import AVFoundation
import Cocoa
import CoreImage
import CoreVideo
import FlutterMacOS
import ImageIO
import XCTest
import Vision

@testable import media_fast_view

private final class FakeSecurityScopedResource: SecurityScopedResource {
  init(path: String, canStart: Bool = true) {
    self.path = path
    self.canStart = canStart
  }

  let path: String
  private let canStart: Bool
  private(set) var startCount = 0
  private(set) var stopCount = 0

  func startAccessingSecurityScopedResource() -> Bool {
    startCount += 1
    return canStart
  }

  func stopAccessingSecurityScopedResource() {
    stopCount += 1
  }
}

final class RunnerTests: XCTestCase {
  func testNestedAcquisitionsReuseTheOriginalResource() throws {
    let resource = FakeSecurityScopedResource(path: "/Library")
    var resolveCount = 0
    let registry = SecurityScopedAccessRegistry(
      resolver: { _ in
        resolveCount += 1
        return resource
      },
      logWarning: { _ in }
    )
    let bookmark = Data([1]).base64EncodedString()

    XCTAssertEqual(try registry.acquire(bookmark), "/Library")
    XCTAssertEqual(try registry.acquire(bookmark), "/Library")
    XCTAssertEqual(resolveCount, 1)
    XCTAssertEqual(resource.startCount, 1)

    registry.release(bookmark)
    XCTAssertEqual(resource.stopCount, 0)

    registry.release(bookmark)
    XCTAssertEqual(resource.stopCount, 1)
  }

  func testReleaseAllBalancesEveryOpenResource() throws {
    let first = FakeSecurityScopedResource(path: "/First")
    let second = FakeSecurityScopedResource(path: "/Second")
    let registry = SecurityScopedAccessRegistry(
      resolver: { data in
        data == Data([1]) ? first : second
      },
      logWarning: { _ in }
    )

    _ = try registry.acquire(Data([1]).base64EncodedString())
    _ = try registry.acquire(Data([2]).base64EncodedString())
    registry.releaseAll()

    XCTAssertEqual(first.stopCount, 1)
    XCTAssertEqual(second.stopCount, 1)
  }

  func testMaximumReaderInspectsEveryGeneratedPresentationFrame() throws {
    let fixture = try makeVideoFixture(colors: [
      (255, 0, 0),
      (0, 255, 0),
      (0, 0, 255),
    ])
    defer { try? FileManager.default.removeItem(at: fixture.url) }

    let registry = SecurityScopedAccessRegistry(logWarning: { _ in })
    let reader = try MaximumVideoFrameReader(
      path: fixture.url.path,
      bookmarkData: nil,
      accessRegistry: registry
    )
    let firstChunk = try reader.readChunk(maximumCount: 128)
    let secondChunk = try reader.readChunk(maximumCount: 128)

    let firstFrames = try XCTUnwrap(firstChunk.payload["frames"] as? [[String: Any]])
    XCTAssertEqual(firstFrames.count, 3)
    XCTAssertTrue(firstChunk.isComplete)
    XCTAssertTrue(secondChunk.isComplete)
    let presentationValues = try firstFrames.map { frame in
      try XCTUnwrap(frame["presentationTimeValue"] as? Int64)
    }
    let presentationScales = try firstFrames.map { frame in
      try XCTUnwrap(frame["presentationTimeScale"] as? Int)
    }
    XCTAssertEqual(presentationScales.count, 3)
    XCTAssertTrue(presentationScales.allSatisfy { $0 > 0 })
    XCTAssertEqual(presentationValues, presentationValues.sorted())
    XCTAssertEqual(presentationValues[0], 0)
    XCTAssertGreaterThan(presentationValues[1], presentationValues[0])
    XCTAssertGreaterThan(presentationValues[2], presentationValues[1])
  }

  func testMaximumReaderCancellationReleasesSecurityScopedBookmark() throws {
    let fixture = try makeVideoFixture(colors: [(255, 0, 0)])
    defer { try? FileManager.default.removeItem(at: fixture.url) }
    let resource = FakeSecurityScopedResource(path: fixture.url.path)
    let registry = SecurityScopedAccessRegistry(
      resolver: { _ in resource },
      logWarning: { _ in }
    )
    let bookmark = Data([99]).base64EncodedString()
    _ = try registry.acquire(bookmark)

    let reader = try MaximumVideoFrameReader(
      path: fixture.url.path,
      bookmarkData: bookmark,
      accessRegistry: registry
    )
    reader.cancel()
    reader.releaseBookmark()

    XCTAssertEqual(resource.startCount, 1)
    XCTAssertEqual(resource.stopCount, 1)
  }

  func testLongVideoChunksStayBoundedAndCancellationIsPrompt() throws {
    let fixture = try makeVideoFixture(
      colors: Array(repeating: (255, 0, 0), count: 180)
    )
    defer { try? FileManager.default.removeItem(at: fixture.url) }
    let reader = try MaximumVideoFrameReader(
      path: fixture.url.path,
      bookmarkData: nil,
      accessRegistry: SecurityScopedAccessRegistry(logWarning: { _ in })
    )

    let firstChunk = try reader.readChunk(maximumCount: 32)
    let frames = try XCTUnwrap(firstChunk.payload["frames"] as? [[String: Any]])
    XCTAssertEqual(frames.count, 32)
    XCTAssertFalse(firstChunk.isComplete)

    let readFinished = expectation(description: "in-flight read cancelled")
    DispatchQueue.global(qos: .utility).async {
      _ = try? reader.readChunk(maximumCount: 128)
      readFinished.fulfill()
    }
    Thread.sleep(forTimeInterval: 0.01)
    let started = Date()
    reader.cancel()
    XCTAssertLessThan(Date().timeIntervalSince(started), 1)
    wait(for: [readFinished], timeout: 1)
    XCTAssertThrowsError(try reader.readChunk(maximumCount: 32))
  }

  func testVisionUsesRevisionOneAndRanksMatchingFrameAheadOfUnrelatedFrame() throws {
    let fixture = try makeVideoFixture(colors: [
      (255, 0, 0),
      (0, 0, 255),
    ])
    defer { try? FileManager.default.removeItem(at: fixture.url) }
    let queryURL = try makePNGFixture(color: (255, 0, 0))
    defer { try? FileManager.default.removeItem(at: queryURL) }
    let resizedQueryURL = try makePNGFixture(
      color: (255, 0, 0),
      width: 64,
      height: 48
    )
    defer { try? FileManager.default.removeItem(at: resizedQueryURL) }
    guard let queryImage = ThumbnailHandler.imageAtPath(queryURL.path),
          let queryPrints = try ThumbnailHandler.featurePrints(for: queryImage) else {
      XCTFail("Could not create the Vision query feature print")
      return
    }

    let result = try ThumbnailHandler.bestVisionFrame(
      path: fixture.url.path,
      requestedTime: CMTime(value: 0, timescale: 30),
      verificationTimes: [
        CMTime(value: 0, timescale: 30),
        CMTime(value: 1, timescale: 30),
      ],
      queryPrints: queryPrints,
      cancellation: VisionCancellationToken()
    )

    let match = try XCTUnwrap(result)
    let unrelated = try XCTUnwrap(ThumbnailHandler.bestVisionFrame(
      path: fixture.url.path,
      requestedTime: CMTime(value: 1, timescale: 30),
      verificationTimes: [CMTime(value: 1, timescale: 30)],
      queryPrints: queryPrints,
      cancellation: VisionCancellationToken()
    ))
    let resizedImage = try XCTUnwrap(
      ThumbnailHandler.imageAtPath(resizedQueryURL.path)
    )
    let resizedPrints = try XCTUnwrap(
      ThumbnailHandler.featurePrints(for: resizedImage)
    )
    let resizedMatch = try XCTUnwrap(ThumbnailHandler.bestVisionFrame(
      path: fixture.url.path,
      requestedTime: CMTime(value: 0, timescale: 30),
      verificationTimes: [CMTime(value: 0, timescale: 30)],
      queryPrints: resizedPrints,
      cancellation: VisionCancellationToken()
    ))
    let crop = try XCTUnwrap(queryImage.cropping(to: CGRect(
      x: 16,
      y: 0,
      width: 96,
      height: 96
    )))
    let cropPrints = try XCTUnwrap(
      ThumbnailHandler.featurePrints(for: crop)
    )
    let cropMatch = try XCTUnwrap(ThumbnailHandler.bestVisionFrame(
      path: fixture.url.path,
      requestedTime: CMTime(value: 0, timescale: 30),
      verificationTimes: [CMTime(value: 0, timescale: 30)],
      queryPrints: cropPrints,
      cancellation: VisionCancellationToken()
    ))
    XCTAssertEqual(match.presentationTime.value, 0)
    XCTAssertGreaterThan(match.presentationTime.timescale, 0)
    XCTAssertLessThan(match.distance, 18.0)
    XCTAssertLessThan(resizedMatch.distance, 25.0)
    XCTAssertLessThan(cropMatch.distance, 35.0)
    XCTAssertGreaterThan(unrelated.distance, 18.0)
    XCTAssertLessThan(match.distance, unrelated.distance)
  }

  func testVisionEqualDistancePrefersEarlierActualPresentationTime() throws {
    let fixture = try makeVideoFixture(colors: [
      (255, 0, 0),
      (255, 0, 0),
    ])
    defer { try? FileManager.default.removeItem(at: fixture.url) }
    let queryURL = try makePNGFixture(color: (255, 0, 0))
    defer { try? FileManager.default.removeItem(at: queryURL) }
    let queryImage = try XCTUnwrap(ThumbnailHandler.imageAtPath(queryURL.path))
    let queryPrints = try XCTUnwrap(
      try ThumbnailHandler.featurePrints(for: queryImage)
    )

    // Reverse the request order so the result proves selection is based on
    // actual PTS, rather than whichever equal-distance frame arrived first.
    let result = try XCTUnwrap(ThumbnailHandler.bestVisionFrame(
      path: fixture.url.path,
      requestedTime: CMTime(value: 1, timescale: 30),
      verificationTimes: [
        CMTime(value: 1, timescale: 30),
        CMTime(value: 0, timescale: 30),
      ],
      queryPrints: queryPrints,
      cancellation: VisionCancellationToken()
    ))

    XCTAssertEqual(CMTimeCompare(result.presentationTime, .zero), 0)
  }

  func testVisionCandidatesAreGroupedOncePerVideo() {
    let groups = ThumbnailHandler.visionCandidateGroups(from: [
      [
        "mediaId": "video-a",
        "path": "/library/a.mp4",
        "timestampMilliseconds": 100,
        "verificationTimestampMilliseconds": [67, 100, 133],
      ],
      [
        "mediaId": "video-b",
        "path": "/library/b.mp4",
        "timestampMilliseconds": 200,
      ],
      [
        "mediaId": "video-a",
        "path": "/library/a.mp4",
        "timestampMilliseconds": 500,
      ],
    ])

    XCTAssertEqual(groups.count, 2)
    XCTAssertEqual(groups[0].path, "/library/a.mp4")
    XCTAssertEqual(groups[0].candidates.count, 2)
    XCTAssertEqual(groups[0].candidates[0].verificationTimes.count, 3)
    XCTAssertEqual(groups[1].path, "/library/b.mp4")
    XCTAssertEqual(groups[1].candidates.count, 1)
  }

  func testVisionCandidateGroupsRetainQueryAndSourceIdentity() {
    let groups = ThumbnailHandler.visionCandidateGroups(from: [
      [
        "queryId": "query-a",
        "sourceFingerprint": "video-fingerprint",
        "mediaId": "video-a",
        "path": "/library/a.mp4",
        "timestampMilliseconds": 100,
      ],
    ])

    XCTAssertEqual(groups.count, 1)
    XCTAssertEqual(groups[0].candidates[0].queryId, "query-a")
    XCTAssertEqual(
      groups[0].candidates[0].sourceFingerprint,
      "video-fingerprint"
    )
  }

  func testVisionFramePrintCacheIsBoundedAndEvictsLeastRecentlyUsedEntry() throws {
    let queryURL = try makePNGFixture(color: (255, 0, 0))
    defer { try? FileManager.default.removeItem(at: queryURL) }
    let image = try XCTUnwrap(ThumbnailHandler.imageAtPath(queryURL.path))
    let prints = try XCTUnwrap(ThumbnailHandler.featurePrints(for: image))
    let cache = VisionFramePrintCache()

    for index in 0...128 {
      cache.insert(
        sourceFingerprint: "video-\(index)",
        presentationTime: CMTime(value: Int64(index), timescale: 30),
        prints: prints
      )
    }

    XCTAssertEqual(cache.count, 128)
    XCTAssertNil(cache.value(
      sourceFingerprint: "video-0",
      presentationTime: CMTime(value: 0, timescale: 30)
    ))
    XCTAssertNotNil(cache.value(
      sourceFingerprint: "video-128",
      presentationTime: CMTime(value: 128, timescale: 30)
    ))
  }

  func testVisionSessionCachePreservesScoresAndAvoidsRepeatedFeaturePrints() throws {
    let fixture = try makeVideoFixture(colors: [
      (255, 0, 0),
      (0, 255, 0),
      (0, 0, 255),
    ])
    defer { try? FileManager.default.removeItem(at: fixture.url) }
    let queryURL = try makePNGFixture(color: (255, 0, 0))
    defer { try? FileManager.default.removeItem(at: queryURL) }
    let queryImage = try XCTUnwrap(ThumbnailHandler.imageAtPath(queryURL.path))
    let queryPrints = try XCTUnwrap(
      ThumbnailHandler.featurePrints(for: queryImage)
    )
    let verifier = try XCTUnwrap(
      ThumbnailHandler.VisionVideoVerifier(path: fixture.url.path)
    )
    let times = [
      CMTime(value: 0, timescale: 30),
      CMTime(value: 1, timescale: 30),
    ]

    ThumbnailHandler.resetTestVisionFeaturePrintCount()
    let uncachedStart = Date()
    let uncachedFirst = try XCTUnwrap(ThumbnailHandler.bestVisionFrame(
      verifier: verifier,
      requestedTime: times[0],
      verificationTimes: times,
      queryPrints: queryPrints,
      cancellation: VisionCancellationToken()
    ))
    let uncachedSecond = try XCTUnwrap(ThumbnailHandler.bestVisionFrame(
      verifier: verifier,
      requestedTime: times[0],
      verificationTimes: times,
      queryPrints: queryPrints,
      cancellation: VisionCancellationToken()
    ))
    let uncachedDuration = Date().timeIntervalSince(uncachedStart)
    let uncachedPrintCount = ThumbnailHandler.testVisionFeaturePrintCount

    ThumbnailHandler.resetTestVisionFeaturePrintCount()
    let cache = VisionFramePrintCache()
    let cachedStart = Date()
    let cachedFirst = try XCTUnwrap(ThumbnailHandler.bestVisionFrame(
      verifier: verifier,
      requestedTime: times[0],
      verificationTimes: times,
      queryPrints: queryPrints,
      cancellation: VisionCancellationToken(),
      cache: cache,
      sourceFingerprint: "fixture",
      throwOnNoFrame: true
    ))
    let cachedSecond = try XCTUnwrap(ThumbnailHandler.bestVisionFrame(
      verifier: verifier,
      requestedTime: times[0],
      verificationTimes: times,
      queryPrints: queryPrints,
      cancellation: VisionCancellationToken(),
      cache: cache,
      sourceFingerprint: "fixture",
      throwOnNoFrame: true
    ))
    let cachedDuration = Date().timeIntervalSince(cachedStart)
    let cachedPrintCount = ThumbnailHandler.testVisionFeaturePrintCount

    XCTAssertEqual(uncachedFirst.presentationTime, cachedFirst.presentationTime)
    XCTAssertEqual(uncachedSecond.presentationTime, cachedSecond.presentationTime)
    XCTAssertEqual(uncachedFirst.distance, cachedFirst.distance, accuracy: 0.0001)
    XCTAssertEqual(uncachedSecond.distance, cachedSecond.distance, accuracy: 0.0001)
    XCTAssertLessThan(cachedPrintCount, uncachedPrintCount)
    XCTAssertEqual(cachedPrintCount, 4)
    XCTAssertEqual(uncachedPrintCount, 8)
    let timingAttachment = XCTAttachment(
      string: "uncached=\(uncachedDuration)s cached=\(cachedDuration)s " +
        "uncachedPrints=\(uncachedPrintCount) cachedPrints=\(cachedPrintCount)"
    )
    timingAttachment.name = "Vision cache same-workload timing"
    timingAttachment.lifetime = .keepAlways
    add(timingAttachment)
  }

  func testVisionSessionMethodLifecycleReturnsMatchesAndProgress() throws {
    let fixture = try makeVideoFixture(colors: [
      (255, 0, 0),
      (0, 0, 255),
    ])
    defer { try? FileManager.default.removeItem(at: fixture.url) }
    let queryURL = try makePNGFixture(color: (255, 0, 0))
    defer { try? FileManager.default.removeItem(at: queryURL) }
    let handler = ThumbnailHandler(
      accessRegistry: SecurityScopedAccessRegistry(logWarning: { _ in })
    )
    var progressEvents = [[String: Any]]()
    handler.setVisionSessionProgressEmitter { payload in
      progressEvents.append(payload)
    }
    ThumbnailHandler.resetTestVisionFeaturePrintCount()

    let started = expectation(description: "Vision session started")
    handler.handle(
      FlutterMethodCall(
        methodName: "startVisionSession",
        arguments: [
          "sessionId": "session-lifecycle",
          "queries": [[
            "queryId": "query-a",
            "path": queryURL.path,
          ], [
            "queryId": "query-b",
            "path": queryURL.path,
          ]],
        ]
      )
    ) { response in
      XCTAssertFalse(response is FlutterError)
      XCTAssertEqual((response as? [String: Any])?["started"] as? Bool, true)
      started.fulfill()
    }
    wait(for: [started], timeout: 5)

    let verified = expectation(description: "Vision batch verified")
    var batch: [String: Any]?
    handler.handle(
      FlutterMethodCall(
        methodName: "verifyVisionSessionBatch",
        arguments: [
          "sessionId": "session-lifecycle",
          "requestId": "batch-lifecycle",
          "candidates": [[
            "queryId": "query-a",
            "mediaId": "video-a",
            "path": fixture.url.path,
            "sourceFingerprint": "fixture-source",
            "timestampMilliseconds": 0,
            "verificationTimestampMilliseconds": [0],
          ], [
            "queryId": "query-b",
            "mediaId": "video-a",
            "path": fixture.url.path,
            "sourceFingerprint": "fixture-source",
            "timestampMilliseconds": 0,
            "verificationTimestampMilliseconds": [0],
          ]],
        ]
      )
    ) { response in
      batch = response as? [String: Any]
      XCTAssertFalse(response is FlutterError)
      verified.fulfill()
    }
    wait(for: [verified], timeout: 10)

    let matches = batch?["matches"] as? [[String: Any]]
    XCTAssertEqual(matches?.count, 2)
    XCTAssertEqual(
      Set(matches?.compactMap { $0["queryId"] as? String } ?? []),
      ["query-a", "query-b"]
    )
    let failures = batch?["failures"] as? [[String: Any]]
    XCTAssertEqual(failures?.count, 0)
    XCTAssertEqual(batch?["completedVideoCount"] as? Int, 1)
    XCTAssertEqual(batch?["verifiedVideoCount"] as? Int, 1)
    XCTAssertEqual(
      Set(matches?.compactMap { $0["mediaId"] as? String } ?? []),
      ["video-a"]
    )
    // The two query IDs point at the same video frame. The first candidate
    // creates two prints (full and center crop); the second is fully cached.
    XCTAssertEqual(ThumbnailHandler.testVisionFeaturePrintCount, 6)
    XCTAssertEqual(progressEvents.count, 1)
    XCTAssertEqual(progressEvents.first?["requestId"] as? String, "batch-lifecycle")
    XCTAssertEqual(progressEvents.first?["mediaId"] as? String, "video-a")

    let ended = expectation(description: "Vision session ended")
    handler.handle(
      FlutterMethodCall(
        methodName: "endVisionSession",
        arguments: ["sessionId": "session-lifecycle"]
      )
    ) { response in
      XCTAssertNil(response)
      ended.fulfill()
    }
    wait(for: [ended], timeout: 2)
  }

  func testVisionCancellationCancelsRegisteredGeneratorWorkThroughParent() {
    let parent = VisionCancellationToken()
    let child = VisionCancellationToken(parent: parent)
    var cancellationCount = 0
    child.register { cancellationCount += 1 }

    parent.cancel()

    XCTAssertTrue(child.isCancelled)
    XCTAssertEqual(cancellationCount, 1)
    XCTAssertThrowsError(try child.checkCancelled())
  }

  func testVisionCancellationIsIdempotentWhenParentAndChildCancelConcurrently() {
    let parent = VisionCancellationToken()
    let child = VisionCancellationToken(parent: parent)
    let countLock = NSLock()
    var cancellationCount = 0
    child.register {
      countLock.lock()
      cancellationCount += 1
      countLock.unlock()
    }

    DispatchQueue.concurrentPerform(iterations: 32) { index in
      if index.isMultiple(of: 2) {
        child.cancel()
      } else {
        parent.cancel()
      }
    }
    child.cancel()
    parent.cancel()

    XCTAssertTrue(parent.isCancelled)
    XCTAssertTrue(child.isCancelled)
    XCTAssertEqual(cancellationCount, 1)
    XCTAssertThrowsError(try child.checkCancelled())
  }

  private struct VideoFixture {
    let url: URL
  }

  private func makeVideoFixture(
    colors: [(UInt8, UInt8, UInt8)]
  ) throws -> VideoFixture {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("mov")
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let width = 128
    let height = 96
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
      ]
    )
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
      ]
    )
    writer.add(input)
    XCTAssertTrue(writer.startWriting())
    writer.startSession(atSourceTime: .zero)
    for (index, color) in colors.enumerated() {
      guard let pixelBuffer = makePixelBuffer(
        width: width,
        height: height,
        color: color
      ) else {
        XCTFail("Could not allocate a test pixel buffer")
        continue
      }
      while !input.isReadyForMoreMediaData {
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
      }
      XCTAssertTrue(
        adaptor.append(
          pixelBuffer,
          withPresentationTime: CMTime(value: Int64(index), timescale: 30)
        )
      )
    }
    input.markAsFinished()
    let finished = expectation(description: "video writer finished")
    writer.finishWriting { finished.fulfill() }
    wait(for: [finished], timeout: 10)
    XCTAssertEqual(
      writer.status,
      .completed,
      writer.error?.localizedDescription ?? ""
    )
    return VideoFixture(url: url)
  }

  private func makePNGFixture(
    color: (UInt8, UInt8, UInt8),
    width: Int = 128,
    height: Int = 96
  ) throws -> URL {
    let pixelBuffer = try XCTUnwrap(
      makePixelBuffer(width: width, height: height, color: color)
    )
    let image = try XCTUnwrap(
      CIContext().createCGImage(
        CIImage(cvPixelBuffer: pixelBuffer),
        from: CGRect(x: 0, y: 0, width: width, height: height)
      )
    )
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("png")
    guard let destination = CGImageDestinationCreateWithURL(
      url as CFURL,
      "public.png" as CFString,
      1,
      nil
    ) else {
      throw NSError(domain: "RunnerTests", code: 1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw NSError(domain: "RunnerTests", code: 2)
    }
    return url
  }

  private func makePixelBuffer(
    width: Int,
    height: Int,
    color: (UInt8, UInt8, UInt8)
  ) -> CVPixelBuffer? {
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_32BGRA,
      nil,
      &pixelBuffer
    )
    guard status == kCVReturnSuccess, let pixelBuffer else { return nil }
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
      return nil
    }
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
    for row in 0..<height {
      for column in 0..<width {
        let offset = row * bytesPerRow + column * 4
        let horizontal = column * 255 / max(width - 1, 1)
        let vertical = row * 255 / max(height - 1, 1)
        let checker = ((row / 12) + (column / 12)).isMultiple(of: 2)
          ? 32
          : 0
        let intensity: Int
        if color.0 >= color.1 && color.0 >= color.2 {
          intensity = min(horizontal + checker, 255)
        } else if color.1 >= color.0 && color.1 >= color.2 {
          intensity = min((horizontal + vertical) / 2 + checker, 255)
        } else {
          intensity = min(vertical + checker, 255)
        }
        bytes[offset] = UInt8(Int(color.2) * intensity / 255)
        bytes[offset + 1] = UInt8(Int(color.1) * intensity / 255)
        bytes[offset + 2] = UInt8(Int(color.0) * intensity / 255)
        bytes[offset + 3] = 255
      }
    }
    return pixelBuffer
  }
}
