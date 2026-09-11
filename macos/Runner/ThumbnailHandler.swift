import AVFoundation
import CoreImage
import CoreVideo
import FlutterMacOS
import Foundation
import ImageIO
import Vision

/// Generates bounded image and video previews without decoding source media in
/// Flutter's UI isolate.
final class ThumbnailHandler: NSObject {
    init(accessRegistry: SecurityScopedAccessRegistry) {
        self.accessRegistry = accessRegistry
        super.init()
    }

    private let accessRegistry: SecurityScopedAccessRegistry
    private let imageQueue = DispatchQueue(
        label: "com.joaquinmx.media_fast_view.thumbnail-images",
        qos: .utility,
        attributes: .concurrent
    )
    private let generatorLock = NSLock()
    private var videoGenerators: [String: AVAssetImageGenerator] = [:]
    private let maximumReaderLock = NSLock()
    private var maximumReaders: [String: MaximumVideoFrameReader] = [:]
    private var cancelledMaximumReaderRequestIds: Set<String> = []
    private let visionTaskLock = NSLock()
    private var visionTasks: [String: VisionCancellationToken] = [:]
    private var cancelledVisionRequestIds: Set<String> = []
    private var visionSessionTasks: [String: Set<String>] = [:]
    private var visionSessions: [String: VisionVerificationSession] = [:]
    private var visionSessionPreparationTokens: [String: VisionCancellationToken] = [:]
    private var cancelledVisionSessionIds: Set<String> = []
    private var visionSessionProgressEmitter: (([String: Any]) -> Void)?

    /// Receives request-scoped progress events that are forwarded to Dart by
    /// [MainFlutterWindow].
    func setVisionSessionProgressEmitter(
        _ emitter: @escaping ([String: Any]) -> Void
    ) {
        visionSessionProgressEmitter = emitter
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "generateThumbnail":
            generateThumbnail(call, result: result)
        case "generateVideoFrames":
            generateVideoFrames(call, result: result)
        case "startMaximumVideoFrameIndex":
            startMaximumVideoFrameIndex(call, result: result)
        case "readMaximumVideoFrameIndexChunk":
            readMaximumVideoFrameIndexChunk(call, result: result)
        case "generateCompactImageDescriptor":
            generateCompactImageDescriptor(call, result: result)
        case "matchVideoFrameVision":
            matchVideoFrameVision(call, result: result)
        case "startVisionSession":
            startVisionSession(call, result: result)
        case "verifyVisionSessionBatch":
            verifyVisionSessionBatch(call, result: result)
        case "endVisionSession":
            endVisionSession(call, result: result)
        case "cancelVisionSession":
            cancelVisionSession(call, result: result)
        case "cancelThumbnail":
            cancelThumbnail(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func generateThumbnail(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let arguments = call.arguments as? [String: Any],
              let requestId = arguments["requestId"] as? String,
              let path = arguments["path"] as? String,
              let mediaType = arguments["mediaType"] as? String,
              let requestedMaxPixelSize = arguments["maxPixelSize"] as? Int else {
            result(invalidArgumentsError())
            return
        }

        let maxPixelSize = min(max(requestedMaxPixelSize, 64), 2048)
        let bookmarkData = arguments["bookmarkData"] as? String
        let videoPositionFraction = arguments["videoPositionFraction"] as? Double

        switch mediaType {
        case "image":
            generateImageThumbnail(
                requestId: requestId,
                path: path,
                maxPixelSize: maxPixelSize,
                bookmarkData: bookmarkData,
                result: result
            )
        case "video":
            generateVideoThumbnail(
                requestId: requestId,
                path: path,
                maxPixelSize: maxPixelSize,
                positionFraction: videoPositionFraction,
                bookmarkData: bookmarkData,
                result: result
            )
        default:
            result(FlutterError(
                code: "UNSUPPORTED_MEDIA_TYPE",
                message: "Only image and video thumbnails are supported",
                details: mediaType
            ))
        }
    }

    private func generateImageThumbnail(
        requestId: String,
        path: String,
        maxPixelSize: Int,
        bookmarkData: String?,
        result: @escaping FlutterResult
    ) {
        imageQueue.async { [weak self] in
            guard let self else { return }

            do {
                let acquiredBookmark = try self.acquire(bookmarkData)
                defer { self.release(acquiredBookmark) }

                guard FileManager.default.fileExists(atPath: path) else {
                    throw ThumbnailGenerationError.fileNotFound(path)
                }

                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                    kCGImageSourceShouldCacheImmediately: false,
                ]
                guard let source = CGImageSourceCreateWithURL(
                    URL(fileURLWithPath: path) as CFURL,
                    nil
                ), let image = CGImageSourceCreateThumbnailAtIndex(
                    source,
                    0,
                    options as CFDictionary
                ) else {
                    throw ThumbnailGenerationError.decodeFailed(path)
                }

                let data = try self.encode(
                    image,
                    type: "public.jpeg" as CFString,
                    quality: 0.82
                )
                self.finish(result, payload: self.payload(data, extension: "jpg"))
            } catch {
                self.finish(result, error: error)
            }
        }
    }

    private func generateVideoThumbnail(
        requestId: String,
        path: String,
        maxPixelSize: Int,
        positionFraction: Double?,
        bookmarkData: String?,
        result: @escaping FlutterResult
    ) {
        do {
            let acquiredBookmark = try acquire(bookmarkData)
            guard FileManager.default.fileExists(atPath: path) else {
                release(acquiredBookmark)
                result(flutterError(for: ThumbnailGenerationError.fileNotFound(path)))
                return
            }

            let asset = AVURLAsset(url: URL(fileURLWithPath: path))
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)

            let durationSeconds = CMTimeGetSeconds(asset.duration)
            let requestedSeconds: Double
            if durationSeconds.isFinite && durationSeconds > 0 {
                let fraction = min(max(positionFraction ?? 0.1, 0), 1)
                requestedSeconds = min(max(durationSeconds * fraction, 0), max(durationSeconds - 0.05, 0))
            } else {
                requestedSeconds = 0
            }
            let requestedTime = CMTime(seconds: requestedSeconds, preferredTimescale: 600)

            setGenerator(generator, for: requestId)
            generator.generateCGImagesAsynchronously(
                forTimes: [NSValue(time: requestedTime)]
            ) { [weak self] _, image, _, generationResult, error in
                guard let self else { return }
                self.removeGenerator(for: requestId)
                defer { self.release(acquiredBookmark) }

                if generationResult == .cancelled {
                    self.finish(result, error: ThumbnailGenerationError.cancelled)
                    return
                }
                if let error {
                    self.finish(result, error: error)
                    return
                }
                guard let image else {
                    self.finish(result, error: ThumbnailGenerationError.decodeFailed(path))
                    return
                }

                do {
                    let data = try self.encode(
                        image,
                        type: "public.jpeg" as CFString,
                        quality: 0.82
                    )
                    self.finish(result, payload: self.payload(data, extension: "jpg"))
                } catch {
                    self.finish(result, error: error)
                }
            }
        } catch {
            result(flutterError(for: error))
        }
    }

    private func generateVideoFrames(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let arguments = call.arguments as? [String: Any],
              let requestId = arguments["requestId"] as? String,
              let path = arguments["path"] as? String,
              let requestedMaxPixelSize = arguments["maxPixelSize"] as? Int,
              let rawPositionPercents = arguments["positionPercents"] as? [NSNumber] else {
            result(invalidVideoFramesArgumentsError())
            return
        }

        let positionPercents = rawPositionPercents.map(\.intValue)
        guard !positionPercents.isEmpty,
              positionPercents.allSatisfy({ (0...100).contains($0) }),
              Set(positionPercents).count == positionPercents.count else {
            result(invalidVideoFramesArgumentsError())
            return
        }

        let maxPixelSize = min(max(requestedMaxPixelSize, 64), 2048)
        let bookmarkData = arguments["bookmarkData"] as? String

        do {
            let acquiredBookmark = try acquire(bookmarkData)
            guard FileManager.default.fileExists(atPath: path) else {
                release(acquiredBookmark)
                result(flutterError(for: ThumbnailGenerationError.fileNotFound(path)))
                return
            }

            let asset = AVURLAsset(url: URL(fileURLWithPath: path))
            let durationSeconds = CMTimeGetSeconds(asset.duration)
            guard durationSeconds.isFinite && durationSeconds > 0 else {
                release(acquiredBookmark)
                result(flutterError(for: ThumbnailGenerationError.decodeFailed(path)))
                return
            }

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)

            let requestedSamples = positionPercents.map { positionPercent in
                let requestedSeconds = min(
                    max(durationSeconds * Double(positionPercent) / 100, 0),
                    max(durationSeconds - 0.05, 0)
                )
                return (
                    positionPercent: positionPercent,
                    time: CMTime(seconds: requestedSeconds, preferredTimescale: 600)
                )
            }
            let requestedTimes = requestedSamples.map { NSValue(time: $0.time) }
            let stateQueue = DispatchQueue(
                label: "com.joaquinmx.media_fast_view.thumbnail-video-frame-result"
            )
            var frames: [[String: Any]] = []
            var firstError: Error?
            var remaining = requestedSamples.count
            var didFinish = false

            setGenerator(generator, for: requestId)
            generator.generateCGImagesAsynchronously(forTimes: requestedTimes) {
                [weak self] requestedTime, image, actualTime, generationResult, error in
                guard let self else { return }

                var frame: [String: Any]?
                var callbackError: Error?
                if generationResult == .cancelled {
                    callbackError = ThumbnailGenerationError.cancelled
                } else if let error {
                    callbackError = error
                } else if let image {
                    do {
                        let data = try self.encode(
                            image,
                            type: "public.jpeg" as CFString,
                            quality: 0.82
                        )
                        let requestedSeconds = CMTimeGetSeconds(requestedTime)
                        let sample = requestedSamples.min { first, second in
                            abs(CMTimeGetSeconds(first.time) - requestedSeconds)
                                < abs(CMTimeGetSeconds(second.time) - requestedSeconds)
                        }!
                        let actualSeconds = max(CMTimeGetSeconds(actualTime), 0)
                        frame = [
                            "positionPercent": sample.positionPercent,
                            "timestampMilliseconds": Int((actualSeconds * 1000).rounded()),
                            "bytes": FlutterStandardTypedData(bytes: data),
                        ]
                    } catch {
                        callbackError = error
                    }
                } else {
                    callbackError = ThumbnailGenerationError.decodeFailed(path)
                }

                stateQueue.async {
                    guard !didFinish else { return }
                    if let frame {
                        frames.append(frame)
                    }
                    if firstError == nil, let callbackError {
                        firstError = callbackError
                    }
                    remaining -= 1
                    guard remaining == 0 else { return }
                    didFinish = true
                    self.removeGenerator(for: requestId)
                    self.release(acquiredBookmark)
                    if let firstError {
                        self.finish(result, error: firstError)
                    } else {
                        frames.sort {
                            ($0["positionPercent"] as? Int ?? 0)
                                < ($1["positionPercent"] as? Int ?? 0)
                        }
                        self.finish(result, payload: ["frames": frames])
                    }
                }
            }
        } catch {
            result(flutterError(for: error))
        }
    }

    private func cancelThumbnail(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let arguments = call.arguments as? [String: Any],
              let requestId = arguments["requestId"] as? String else {
            result(invalidArgumentsError())
            return
        }

        generatorLock.lock()
        let generator = videoGenerators[requestId]
        generatorLock.unlock()
        generator?.cancelAllCGImageGeneration()
        maximumReaderLock.lock()
        let maximumReader = maximumReaders.removeValue(forKey: requestId)
        if maximumReader == nil, requestId.hasPrefix("maximum-") {
            cancelledMaximumReaderRequestIds.insert(requestId)
        }
        maximumReaderLock.unlock()
        maximumReader?.cancel()
        visionTaskLock.lock()
        let visionTask = visionTasks.removeValue(forKey: requestId)
        if visionTask == nil, requestId.hasPrefix("vision-") {
            cancelledVisionRequestIds.insert(requestId)
        }
        visionTaskLock.unlock()
        visionTask?.cancel()
        result(nil)
    }

    // MARK: Maximum-precision frame indexing

    private func startMaximumVideoFrameIndex(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let arguments = call.arguments as? [String: Any],
              let requestId = arguments["requestId"] as? String,
              let path = arguments["path"] as? String else {
            result(invalidMaximumIndexArgumentsError())
            return
        }
        let bookmarkData = arguments["bookmarkData"] as? String
        maximumReaderLock.lock()
        if cancelledMaximumReaderRequestIds.remove(requestId) != nil {
            maximumReaderLock.unlock()
            result(flutterError(for: ThumbnailGenerationError.cancelled))
            return
        }
        let previous = maximumReaders.removeValue(forKey: requestId)
        maximumReaderLock.unlock()
        previous?.cancel()

        var acquiredBookmark: String?
        do {
            acquiredBookmark = try acquire(bookmarkData)
            guard FileManager.default.fileExists(atPath: path) else {
                release(acquiredBookmark)
                acquiredBookmark = nil
                result(flutterError(for: ThumbnailGenerationError.fileNotFound(path)))
                return
            }
            let reader = try MaximumVideoFrameReader(
                path: path,
                bookmarkData: acquiredBookmark,
                accessRegistry: accessRegistry
            )
            var cancelledBeforeRegistration = false
            maximumReaderLock.lock()
            if cancelledMaximumReaderRequestIds.remove(requestId) != nil {
                cancelledBeforeRegistration = true
            } else {
                maximumReaders[requestId] = reader
            }
            maximumReaderLock.unlock()
            if cancelledBeforeRegistration {
                reader.cancel()
                acquiredBookmark = nil
                result(flutterError(for: ThumbnailGenerationError.cancelled))
                return
            }
            acquiredBookmark = nil
            result(nil)
        } catch {
            release(acquiredBookmark)
            result(flutterError(for: error))
        }
    }

    private func readMaximumVideoFrameIndexChunk(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let arguments = call.arguments as? [String: Any],
              let requestId = arguments["requestId"] as? String else {
            result(invalidMaximumIndexArgumentsError())
            return
        }
        let requestedChunkSize = (arguments["chunkSize"] as? Int) ?? 128
        let chunkSize = min(max(requestedChunkSize, 1), 256)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            self.maximumReaderLock.lock()
            let reader = self.maximumReaders[requestId]
            let wasCancelledBeforeRead = self.cancelledMaximumReaderRequestIds.remove(requestId) != nil
            self.maximumReaderLock.unlock()
            if wasCancelledBeforeRead {
                self.finish(
                    result,
                    error: ThumbnailGenerationError.cancelled
                )
                return
            }
            guard let reader else {
                self.finish(
                    result,
                    error: ThumbnailGenerationError.decodeFailed("maximum index request")
                )
                return
            }
            do {
                let response = try reader.readChunk(maximumCount: chunkSize)
                if response.isComplete {
                    self.maximumReaderLock.lock()
                    self.maximumReaders.removeValue(forKey: requestId)
                    self.maximumReaderLock.unlock()
                    reader.releaseBookmark()
                }
                self.finish(result, payload: response.payload)
            } catch {
                self.maximumReaderLock.lock()
                self.maximumReaders.removeValue(forKey: requestId)
                self.maximumReaderLock.unlock()
                reader.cancel()
                self.finish(result, error: error)
            }
        }
    }

    private func generateCompactImageDescriptor(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let arguments = call.arguments as? [String: Any],
              let path = arguments["path"] as? String else {
            result(invalidArgumentsError())
            return
        }
        let bookmarkData = arguments["bookmarkData"] as? String
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            do {
                let acquiredBookmark = try self.acquire(bookmarkData)
                defer { self.release(acquiredBookmark) }
                guard let source = CGImageSourceCreateWithURL(
                    URL(fileURLWithPath: path) as CFURL,
                    nil
                ), let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 2048,
                    kCGImageSourceShouldCacheImmediately: false,
                ] as CFDictionary) else {
                    throw ThumbnailGenerationError.decodeFailed(path)
                }
                self.finish(
                    result,
                    payload: try MaximumVideoFrameDescriptorBuilder.payload(for: image)
                )
            } catch {
                self.finish(result, error: error)
            }
        }
    }

    // MARK: Vision verification

    private func matchVideoFrameVision(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let arguments = call.arguments as? [String: Any],
              let requestId = arguments["requestId"] as? String,
              let queryPath = arguments["queryPath"] as? String,
              let rawCandidates = arguments["candidates"] as? [[String: Any]] else {
            result(invalidVisionArgumentsError())
            return
        }
        let queryBookmarkData = arguments["queryBookmarkData"] as? String
        visionTaskLock.lock()
        if cancelledVisionRequestIds.remove(requestId) != nil {
            visionTaskLock.unlock()
            result(flutterError(for: ThumbnailGenerationError.cancelled))
            return
        }
        let previousTask = visionTasks.removeValue(forKey: requestId)
        let task = VisionCancellationToken()
        visionTasks[requestId] = task
        visionTaskLock.unlock()
        previousTask?.cancel()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            defer {
                self.visionTaskLock.lock()
                if self.visionTasks[requestId] === task {
                    self.visionTasks.removeValue(forKey: requestId)
                }
                self.cancelledVisionRequestIds.remove(requestId)
                self.visionTaskLock.unlock()
            }
            do {
                try task.checkCancelled()
                let acquiredQueryBookmark = try self.acquire(queryBookmarkData)
                defer { self.release(acquiredQueryBookmark) }
                guard let queryImage = Self.imageAtPath(queryPath),
                      let queryPrints = try Self.featurePrints(for: queryImage) else {
                    throw ThumbnailGenerationError.decodeFailed(queryPath)
                }
                var matches: [[String: Any]] = []
                let candidateGroups = Self.visionCandidateGroups(from: rawCandidates)
                for group in candidateGroups {
                    try task.checkCancelled()
                    let acquiredBookmark = try self.acquire(group.bookmarkData)
                    defer { self.release(acquiredBookmark) }
                    guard let verifier = VisionVideoVerifier(path: group.path) else {
                        continue
                    }
                    for request in group.candidates {
                        try task.checkCancelled()
                        let candidate = try Self.bestVisionFrame(
                            verifier: verifier,
                            requestedTime: request.requestedTime,
                            verificationTimes: request.verificationTimes,
                            queryPrints: queryPrints,
                            cancellation: task
                        )
                        if let candidate {
                            matches.append([
                                "mediaId": request.mediaId,
                                "visionDistance": candidate.distance,
                                "timestampMilliseconds": candidate.timestampMilliseconds,
                                "presentationTimeValue": candidate.presentationTime.value,
                                "presentationTimeScale": Int(candidate.presentationTime.timescale),
                                "positionPercent": candidate.positionPercent,
                            ])
                        }
                    }
                }
                try task.checkCancelled()
                self.finish(result, payload: ["matches": matches])
            } catch {
                self.finish(result, error: error)
            }
        }
    }

    // MARK: Shared Vision verification sessions

    /// Prepares query feature prints once so one verification pass can serve
    /// several image queries. The session owns no decoded pixels.
    private func startVisionSession(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let arguments = call.arguments as? [String: Any],
              let sessionId = arguments["sessionId"] as? String,
              let rawQueries = arguments["queries"] as? [[String: Any]],
              !sessionId.isEmpty else {
            result(invalidVisionSessionArgumentsError())
            return
        }

        visionTaskLock.lock()
        if cancelledVisionSessionIds.remove(sessionId) != nil {
            visionTaskLock.unlock()
            result(flutterError(for: ThumbnailGenerationError.cancelled))
            return
        }
        let previous = visionSessions.removeValue(forKey: sessionId)
        let previousPreparation = visionSessionPreparationTokens.removeValue(
            forKey: sessionId
        )
        let preparation = VisionCancellationToken()
        visionSessionPreparationTokens[sessionId] = preparation
        visionTaskLock.unlock()
        previous?.cancel()
        previousPreparation?.cancel()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                var queryPrints: [String: VisionPrints] = [:]
                for rawQuery in rawQueries {
                    try preparation.checkCancelled()
                    try self.checkVisionSessionCancellation(sessionId)
                    guard let queryId = rawQuery["queryId"] as? String,
                          !queryId.isEmpty,
                          let path = rawQuery["path"] as? String else {
                        throw ThumbnailGenerationError.invalidVisionRequest
                    }
                    let bookmarkData = rawQuery["bookmarkData"] as? String
                    let acquiredBookmark = try self.acquire(bookmarkData)
                    defer { self.release(acquiredBookmark) }
                    guard let image = Self.imageAtPath(path),
                          let prints = try Self.featurePrints(
                              for: image,
                              cancellation: preparation
                          ) else {
                        throw ThumbnailGenerationError.decodeFailed(path)
                    }
                    guard queryPrints[queryId] == nil else {
                        throw ThumbnailGenerationError.invalidVisionRequest
                    }
                    queryPrints[queryId] = prints
                }
                guard !queryPrints.isEmpty else {
                    throw ThumbnailGenerationError.invalidVisionRequest
                }
                let session = VisionVerificationSession(queryPrints: queryPrints)
                self.visionTaskLock.lock()
                let isCurrentPreparation =
                    self.visionSessionPreparationTokens[sessionId] === preparation
                if isCurrentPreparation {
                    self.visionSessionPreparationTokens.removeValue(
                        forKey: sessionId
                    )
                }
                let wasCancelled = self.cancelledVisionSessionIds.remove(sessionId) != nil
                if isCurrentPreparation && !wasCancelled {
                    self.visionSessions[sessionId] = session
                }
                self.visionTaskLock.unlock()
                if !isCurrentPreparation || wasCancelled {
                    session.cancel()
                    throw ThumbnailGenerationError.cancelled
                }
                self.finish(result, payload: ["started": true])
            } catch {
                self.visionTaskLock.lock()
                if self.visionSessionPreparationTokens[sessionId] === preparation {
                    self.visionSessionPreparationTokens.removeValue(forKey: sessionId)
                    self.visionSessions.removeValue(forKey: sessionId)
                }
                if self.visionSessionPreparationTokens[sessionId] == nil,
                   self.visionSessions[sessionId] == nil,
                   self.visionSessionTasks[sessionId] == nil {
                    self.cancelledVisionSessionIds.remove(sessionId)
                }
                self.visionTaskLock.unlock()
                self.finish(result, error: error)
            }
        }
    }

    private func verifyVisionSessionBatch(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let arguments = call.arguments as? [String: Any],
              let sessionId = arguments["sessionId"] as? String,
              let requestId = arguments["requestId"] as? String,
              let rawCandidates = arguments["candidates"] as? [[String: Any]],
              !sessionId.isEmpty,
              !requestId.isEmpty else {
            result(invalidVisionSessionArgumentsError())
            return
        }
        visionTaskLock.lock()
        guard let session = visionSessions[sessionId] else {
            visionTaskLock.unlock()
            result(FlutterError(
                code: "VISION_SESSION_NOT_FOUND",
                message: "The Vision session is no longer available",
                details: sessionId
            ))
            return
        }
        if cancelledVisionSessionIds.contains(sessionId) {
            visionTaskLock.unlock()
            result(flutterError(for: ThumbnailGenerationError.cancelled))
            return
        }
        let task = VisionCancellationToken(parent: session.cancellation)
        visionTasks[requestId] = task
        visionSessionTasks[sessionId, default: []].insert(requestId)
        visionTaskLock.unlock()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            defer {
                self.visionTaskLock.lock()
                self.visionTasks.removeValue(forKey: requestId)
                self.visionSessionTasks[sessionId]?.remove(requestId)
                if self.visionSessionTasks[sessionId]?.isEmpty == true {
                    self.visionSessionTasks.removeValue(forKey: sessionId)
                }
                if self.visionSessionTasks[sessionId] == nil,
                   self.visionSessionPreparationTokens[sessionId] == nil,
                   self.visionSessions[sessionId] == nil {
                    self.cancelledVisionSessionIds.remove(sessionId)
                }
                self.visionTaskLock.unlock()
            }
            do {
                let groups = Self.visionCandidateGroups(from: rawCandidates)
                var matches: [[String: Any]] = []
                var failures: [[String: Any]] = []
                var verifiedVideoCount = 0
                var completedVideoCount = 0
                for group in groups {
                    try task.checkCancelled()
                    let groupMatchStart = matches.count
                    do {
                        let acquiredBookmark = try self.acquire(group.bookmarkData)
                        defer { self.release(acquiredBookmark) }
                        guard let verifier = VisionVideoVerifier(path: group.path) else {
                            throw ThumbnailGenerationError.decodeFailed(group.path)
                        }
                        let removeGeneratorCancellation = task.register {
                            verifier.generator.cancelAllCGImageGeneration()
                        }
                        defer { removeGeneratorCancellation() }
                        for request in group.candidates {
                            try task.checkCancelled()
                            guard let queryPrints = session.queryPrints[request.queryId]
                            else {
                                throw ThumbnailGenerationError.invalidVisionRequest
                            }
                            let candidate = try Self.bestVisionFrame(
                                verifier: verifier,
                                requestedTime: request.requestedTime,
                                verificationTimes: request.verificationTimes,
                                queryPrints: queryPrints,
                                cancellation: task,
                                cache: session.cache,
                                sourceFingerprint: "\(request.sourceFingerprint ?? "")|\(group.path)",
                                throwOnNoFrame: true
                            )
                            if let candidate {
                                let match: [String: Any] = [
                                    "mediaId": request.mediaId,
                                    "queryId": request.queryId,
                                    "visionDistance": candidate.distance,
                                    "timestampMilliseconds": candidate.timestampMilliseconds,
                                    "presentationTimeValue": candidate.presentationTime.value,
                                    "presentationTimeScale": Int(candidate.presentationTime.timescale),
                                    "positionPercent": candidate.positionPercent,
                                ]
                                matches.append(match)
                            }
                        }
                        verifiedVideoCount += 1
                        completedVideoCount += 1
                        self.emitVisionSessionUpdate(
                            sessionId: sessionId,
                            requestId: requestId,
                            mediaId: group.candidates.first?.mediaId ?? group.path,
                            matches: Array(matches[groupMatchStart..<matches.count]),
                            completedVideoCount: completedVideoCount,
                            verifiedVideoCount: verifiedVideoCount,
                            failureMessage: nil
                        )
                    } catch let error as ThumbnailGenerationError {
                        if case .cancelled = error {
                            throw error
                        }
                        failures.append([
                            "mediaId": group.candidates.first?.mediaId ?? group.path,
                            "message": error.localizedDescription,
                        ])
                        completedVideoCount += 1
                        self.emitVisionSessionUpdate(
                            sessionId: sessionId,
                            requestId: requestId,
                            mediaId: group.candidates.first?.mediaId ?? group.path,
                            matches: [],
                            completedVideoCount: completedVideoCount,
                            verifiedVideoCount: verifiedVideoCount,
                            failureMessage: error.localizedDescription
                        )
                    } catch {
                        failures.append([
                            "mediaId": group.candidates.first?.mediaId ?? group.path,
                            "message": error.localizedDescription,
                        ])
                        completedVideoCount += 1
                        self.emitVisionSessionUpdate(
                            sessionId: sessionId,
                            requestId: requestId,
                            mediaId: group.candidates.first?.mediaId ?? group.path,
                            matches: [],
                            completedVideoCount: completedVideoCount,
                            verifiedVideoCount: verifiedVideoCount,
                            failureMessage: error.localizedDescription
                        )
                    }
                }
                try task.checkCancelled()
                self.finish(result, payload: [
                    "matches": matches,
                    "failures": failures,
                    "completedVideoCount": completedVideoCount,
                    "verifiedVideoCount": verifiedVideoCount,
                ])
            } catch {
                self.finish(result, error: error)
            }
        }
    }

    private func endVisionSession(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let sessionId = (call.arguments as? [String: Any])?["sessionId"] as? String
        else {
            result(invalidVisionSessionArgumentsError())
            return
        }
        visionTaskLock.lock()
        let session = visionSessions.removeValue(forKey: sessionId)
        let preparation = visionSessionPreparationTokens.removeValue(forKey: sessionId)
        let taskIds = visionSessionTasks.removeValue(forKey: sessionId) ?? []
        let tasks = taskIds.compactMap { visionTasks[$0] }
        visionTaskLock.unlock()
        session?.cancel()
        preparation?.cancel()
        for task in tasks {
            task.cancel()
        }
        result(nil)
    }

    private func cancelVisionSession(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let sessionId = (call.arguments as? [String: Any])?["sessionId"] as? String
        else {
            result(invalidVisionSessionArgumentsError())
            return
        }
        visionTaskLock.lock()
        cancelledVisionSessionIds.insert(sessionId)
        let session = visionSessions.removeValue(forKey: sessionId)
        let preparation = visionSessionPreparationTokens.removeValue(forKey: sessionId)
        let taskIds = visionSessionTasks[sessionId] ?? []
        let tasks = taskIds.compactMap { visionTasks[$0] }
        if tasks.isEmpty && preparation == nil && session == nil {
            cancelledVisionSessionIds.remove(sessionId)
        }
        visionTaskLock.unlock()
        session?.cancel()
        preparation?.cancel()
        for task in tasks {
            task.cancel()
        }
        result(nil)
    }

    private func checkVisionSessionCancellation(_ sessionId: String) throws {
        visionTaskLock.lock()
        let cancelled = cancelledVisionSessionIds.contains(sessionId)
        let session = visionSessions[sessionId]
        visionTaskLock.unlock()
        if cancelled {
            throw ThumbnailGenerationError.cancelled
        }
        try session?.cancellation.checkCancelled()
    }

    private func emitVisionSessionUpdate(
        sessionId: String,
        requestId: String,
        mediaId: String,
        matches: [[String: Any]],
        completedVideoCount: Int,
        verifiedVideoCount: Int,
        failureMessage: String?
    ) {
        var payload: [String: Any] = [
            "sessionId": sessionId,
            "requestId": requestId,
            "mediaId": mediaId,
            "matches": matches,
            "completedVideoCount": completedVideoCount,
            "verifiedVideoCount": verifiedVideoCount,
        ]
        if let failureMessage {
            payload["failureMessage"] = failureMessage
        }
        visionSessionProgressEmitter?(payload)
    }

    private func acquire(_ bookmarkData: String?) throws -> String? {
        guard let bookmarkData, !bookmarkData.isEmpty else { return nil }
        _ = try accessRegistry.acquire(bookmarkData)
        return bookmarkData
    }

    private func release(_ bookmarkData: String?) {
        guard let bookmarkData else { return }
        accessRegistry.release(bookmarkData)
    }

    private func setGenerator(_ generator: AVAssetImageGenerator, for requestId: String) {
        generatorLock.lock()
        videoGenerators[requestId] = generator
        generatorLock.unlock()
    }

    private func removeGenerator(for requestId: String) {
        generatorLock.lock()
        videoGenerators.removeValue(forKey: requestId)
        generatorLock.unlock()
    }

    private func encode(_ image: CGImage, type: CFString, quality: Double) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            type,
            1,
            nil
        ) else {
            throw ThumbnailGenerationError.encodeFailed
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw ThumbnailGenerationError.encodeFailed
        }
        return data as Data
    }

    private func payload(_ data: Data, extension fileExtension: String) -> [String: Any] {
        return [
            "bytes": FlutterStandardTypedData(bytes: data),
            "extension": fileExtension,
        ]
    }

    private func finish(_ result: @escaping FlutterResult, payload: [String: Any]) {
        DispatchQueue.main.async { result(payload) }
    }

    private func finish(_ result: @escaping FlutterResult, error: Error) {
        DispatchQueue.main.async { result(self.flutterError(for: error)) }
    }

    private func invalidArgumentsError() -> FlutterError {
        return FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "requestId, path, mediaType, and maxPixelSize are required",
            details: nil
        )
    }

    private func invalidVideoFramesArgumentsError() -> FlutterError {
        return FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "requestId, path, maxPixelSize, and unique positionPercents are required",
            details: nil
        )
    }

    private func invalidMaximumIndexArgumentsError() -> FlutterError {
        return FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "requestId and path are required for maximum frame indexing",
            details: nil
        )
    }

    private func invalidVisionArgumentsError() -> FlutterError {
        return FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "requestId, queryPath, and candidates are required for Vision matching",
            details: nil
        )
    }

    private func invalidVisionSessionArgumentsError() -> FlutterError {
        return FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "sessionId, requestId, queries, and candidates are required for Vision sessions",
            details: nil
        )
    }

    private func flutterError(for error: Error) -> FlutterError {
        if case ThumbnailGenerationError.cancelled = error {
            return FlutterError(code: "CANCELLED", message: "Thumbnail generation was cancelled", details: nil)
        }
        return FlutterError(
            code: "THUMBNAIL_GENERATION_FAILED",
            message: error.localizedDescription,
            details: nil
        )
    }
}

/// Owns one sequential AVAssetReader pass. The reader never stores decoded
/// pixels; only the bounded descriptor response is retained until Flutter
/// persists it.
final class MaximumVideoFrameReader {
    struct Chunk {
        let payload: [String: Any]
        let isComplete: Bool
    }

    init(
        path: String,
        bookmarkData: String?,
        accessRegistry: SecurityScopedAccessRegistry
    ) throws {
        self.bookmarkData = bookmarkData
        self.accessRegistry = accessRegistry
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw ThumbnailGenerationError.decodeFailed(path)
        }
        let newReader = try AVAssetReader(asset: asset)
        let newOutput = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_32BGRA,
            ]
        )
        newOutput.alwaysCopiesSampleData = false
        guard newReader.canAdd(newOutput) else {
            throw ThumbnailGenerationError.decodeFailed(path)
        }
        newReader.add(newOutput)
        guard newReader.startReading() else {
            throw newReader.error ?? ThumbnailGenerationError.decodeFailed(path)
        }
        reader = newReader
        output = newOutput
        transform = track.preferredTransform
    }

    private let reader: AVAssetReader
    private let output: AVAssetReaderTrackOutput
    private let transform: CGAffineTransform
    private let bookmarkData: String?
    private let accessRegistry: SecurityScopedAccessRegistry
    private let lock = NSLock()
    private var frameIndex = 0
    private var didReachEnd = false
    private var didCancel = false
    private var didReleaseBookmark = false

    func readChunk(maximumCount: Int) throws -> Chunk {
        lock.lock()
        let reachedEnd = didReachEnd
        let cancelled = didCancel
        lock.unlock()
        if cancelled {
            throw ThumbnailGenerationError.cancelled
        }
        if reachedEnd {
            return Chunk(payload: ["frames": [], "isComplete": true], isComplete: true)
        }
        var frames: [[String: Any]] = []
        while frames.count < maximumCount {
            try checkCancelled()
            guard let sampleBuffer = output.copyNextSampleBuffer() else {
                let status = reader.status
                lock.lock()
                didReachEnd = true
                releaseBookmarkLocked()
                let wasCancelled = didCancel
                lock.unlock()
                if wasCancelled || status == .cancelled {
                    throw ThumbnailGenerationError.cancelled
                }
                if status == .failed {
                    throw reader.error ?? ThumbnailGenerationError.decodeFailed("video frame reader")
                }
                if status != .completed {
                    throw ThumbnailGenerationError.decodeFailed("video frame reader ended before completion")
                }
                break
            }
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                throw ThumbnailGenerationError.pixelBufferMissing
            }
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            guard presentationTime.isValid,
                  !presentationTime.isIndefinite,
                  presentationTime.timescale > 0,
                  CMTimeGetSeconds(presentationTime).isFinite else {
                throw ThumbnailGenerationError.invalidPresentationTime
            }
            let orientedImage = try MaximumVideoFrameDescriptorBuilder.orientedImage(
                pixelBuffer: pixelBuffer,
                transform: transform
            )
            let descriptor = try MaximumVideoFrameDescriptorBuilder.payload(
                for: orientedImage,
                frameIndex: frameIndex,
                presentationTime: presentationTime
            )
            frames.append(descriptor)
            frameIndex += 1
        }
        try checkCancelled()
        return Chunk(
            payload: ["frames": frames, "isComplete": didReachEnd],
            isComplete: didReachEnd
        )
    }

    func cancel() {
        lock.lock()
        didCancel = true
        didReachEnd = true
        releaseBookmarkLocked()
        lock.unlock()
        reader.cancelReading()
    }

    func releaseBookmark() {
        lock.lock()
        releaseBookmarkLocked()
        lock.unlock()
    }

    private func releaseBookmarkLocked() {
        guard !didReleaseBookmark else { return }
        didReleaseBookmark = true
        if let bookmarkData {
            accessRegistry.release(bookmarkData)
        }
    }

    private func checkCancelled() throws {
        lock.lock()
        let cancelled = didCancel
        lock.unlock()
        if cancelled {
            throw ThumbnailGenerationError.cancelled
        }
    }
}

enum MaximumVideoFrameDescriptorBuilder {
    private static let context = CIContext(options: nil)
    private static let hashWidth = 9
    private static let hashHeight = 8

    static func orientedImage(
        pixelBuffer: CVPixelBuffer,
        transform: CGAffineTransform
    ) throws -> CGImage {
        let image = CIImage(cvPixelBuffer: pixelBuffer).transformed(by: transform)
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else {
            throw ThumbnailGenerationError.orientationFailed
        }
        let translated = image.transformed(
            by: CGAffineTransform(
                translationX: -extent.minX,
                y: -extent.minY
            )
        )
        guard let output = context.createCGImage(
            translated,
            from: CGRect(origin: .zero, size: extent.size)
        ) else {
            throw ThumbnailGenerationError.orientationFailed
        }
        return output
    }

    static func payload(for image: CGImage) throws -> [String: Any] {
        return try payload(for: image, frameIndex: 0, presentationTime: nil)
    }

    static func payload(
        for image: CGImage,
        frameIndex: Int,
        presentationTime: CMTime?
    ) throws -> [String: Any] {
        var payload: [String: Any] = [
            "frameIndex": frameIndex,
            "fullFrameHash": try signedHash(for: image),
            "centerCropHash": try signedHash(for: centerCrop(of: image)),
            "width": image.width,
            "height": image.height,
        ]
        if let presentationTime {
            payload["timestampMilliseconds"] = Int(
                (CMTimeGetSeconds(presentationTime) * 1000).rounded()
            )
            payload["presentationTimeValue"] = presentationTime.value
            payload["presentationTimeScale"] = Int(presentationTime.timescale)
        }
        return payload
    }

    private static func centerCrop(of image: CGImage) throws -> CGImage {
        return try centerCropImage(of: image)
    }

    static func centerCropImage(of image: CGImage) throws -> CGImage {
        let side = min(image.width, image.height)
        guard side > 0 else {
            throw ThumbnailGenerationError.cropFailed
        }
        let originX = (image.width - side) / 2
        let originY = (image.height - side) / 2
        guard let crop = image.cropping(to: CGRect(
            x: originX,
            y: originY,
            width: side,
            height: side
        )) else {
            throw ThumbnailGenerationError.cropFailed
        }
        return crop
    }

    private static func signedHash(for image: CGImage) throws -> Int64 {
        var pixels = [UInt8](repeating: 0, count: hashWidth * hashHeight)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        try pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: hashWidth,
                height: hashHeight,
                bitsPerComponent: 8,
                bytesPerRow: hashWidth,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else {
                throw ThumbnailGenerationError.hashFailed
            }
            context.interpolationQuality = .high
            context.draw(
                image,
                in: CGRect(x: 0, y: 0, width: hashWidth, height: hashHeight)
            )
        }
        var value: UInt64 = 0
        for row in 0..<hashHeight {
            for column in 0..<(hashWidth - 1) {
                let left = pixels[row * hashWidth + column]
                let right = pixels[row * hashWidth + column + 1]
                value = (value << 1) | (left < right ? 1 : 0)
            }
        }
        return Int64(bitPattern: value)
    }
}

extension ThumbnailHandler {
    private static let visionFeaturePrintCounterLock = NSLock()
    private static var visionFeaturePrintCounter = 0

    /// Test-only instrumentation for comparing cached and uncached workloads.
    static var testVisionFeaturePrintCount: Int {
        visionFeaturePrintCounterLock.lock()
        let count = visionFeaturePrintCounter
        visionFeaturePrintCounterLock.unlock()
        return count
    }

    /// Resets test-only Vision feature-print instrumentation.
    static func resetTestVisionFeaturePrintCount() {
        visionFeaturePrintCounterLock.lock()
        visionFeaturePrintCounter = 0
        visionFeaturePrintCounterLock.unlock()
    }

    private static func recordVisionFeaturePrint() {
        visionFeaturePrintCounterLock.lock()
        visionFeaturePrintCounter += 1
        visionFeaturePrintCounterLock.unlock()
    }

    struct VisionCandidateRequest {
        let mediaId: String
        let queryId: String
        let sourceFingerprint: String?
        let requestedTime: CMTime
        let verificationTimes: [CMTime]
    }

    struct VisionCandidateGroup {
        let path: String
        let bookmarkData: String?
        var candidates: [VisionCandidateRequest]
    }

    /// Groups requests by video while retaining their first-seen order.
    /// Production creates one asset/generator and security-scope lease per
    /// group instead of repeating that work for every candidate window.
    static func visionCandidateGroups(
        from rawCandidates: [[String: Any]]
    ) -> [VisionCandidateGroup] {
        var groups: [VisionCandidateGroup] = []
        var groupIndexByMediaId: [String: Int] = [:]
        for rawCandidate in rawCandidates {
            guard let mediaId = rawCandidate["mediaId"] as? String,
                  let path = rawCandidate["path"] as? String,
                  let timestampMilliseconds = rawCandidate[
                    "timestampMilliseconds"
                  ] as? Int else {
                continue
            }
            let queryId = rawCandidate["queryId"] as? String ?? "legacy"
            let requestedTime = cmTime(
                value: rawCandidate["presentationTimeValue"],
                timescale: rawCandidate["presentationTimeScale"]
            ) ?? CMTime(
                value: Int64(timestampMilliseconds),
                timescale: 1000
            )
            let rationalTimes =
                (rawCandidate["verificationPresentationTimes"] as? [[String: Any]])?
                .compactMap { value in
                    cmTime(value: value["value"], timescale: value["timescale"])
                } ?? []
            let verificationTimes = rationalTimes.isEmpty
                ? ((rawCandidate["verificationTimestampMilliseconds"] as? [Int]) ??
                    [timestampMilliseconds]).map {
                        CMTime(value: Int64($0), timescale: 1000)
                    }
                : rationalTimes
            let request = VisionCandidateRequest(
                mediaId: mediaId,
                queryId: queryId,
                sourceFingerprint: rawCandidate["sourceFingerprint"] as? String,
                requestedTime: requestedTime,
                verificationTimes: verificationTimes
            )
            if let groupIndex = groupIndexByMediaId[mediaId] {
                groups[groupIndex].candidates.append(request)
            } else {
                groupIndexByMediaId[mediaId] = groups.count
                groups.append(VisionCandidateGroup(
                    path: path,
                    bookmarkData: rawCandidate["bookmarkData"] as? String,
                    candidates: [request]
                ))
            }
        }
        return groups
    }

    struct VisionFrameResult {
        let distance: Double
        let presentationTime: CMTime
        let timestampMilliseconds: Int
        let positionPercent: Int
    }

    static func imageAtPath(_ path: String) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(
            URL(fileURLWithPath: path) as CFURL,
            nil
        ) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2048,
            kCGImageSourceShouldCacheImmediately: false,
        ] as CFDictionary)
    }

    struct VisionPrints {
        let full: VNFeaturePrintObservation
        let centerCrop: VNFeaturePrintObservation
    }

    static func featurePrints(for image: CGImage) throws -> VisionPrints? {
        let cropImage = try MaximumVideoFrameDescriptorBuilder.centerCropImage(
            of: image
        )
        guard let full = try featurePrint(for: image),
              let centerCrop = try featurePrint(for: cropImage) else {
            return nil
        }
        return VisionPrints(full: full, centerCrop: centerCrop)
    }

    static func featurePrints(
        for image: CGImage,
        cancellation: VisionCancellationToken?
    ) throws -> VisionPrints? {
        try cancellation?.checkCancelled()
        let cropImage = try MaximumVideoFrameDescriptorBuilder.centerCropImage(
            of: image
        )
        guard let full = try featurePrint(for: image, cancellation: cancellation),
              let centerCrop = try featurePrint(
                  for: cropImage,
                  cancellation: cancellation
              ) else {
            return nil
        }
        try cancellation?.checkCancelled()
        return VisionPrints(full: full, centerCrop: centerCrop)
    }

    static func featurePrint(for image: CGImage) throws -> VNFeaturePrintObservation? {
        recordVisionFeaturePrint()
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = VNGenerateImageFeaturePrintRequestRevision1
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        return request.results?.first as? VNFeaturePrintObservation
    }

    static func featurePrint(
        for image: CGImage,
        cancellation: VisionCancellationToken?
    ) throws -> VNFeaturePrintObservation? {
        try cancellation?.checkCancelled()
        recordVisionFeaturePrint()
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = VNGenerateImageFeaturePrintRequestRevision1
        let removeCancellation = cancellation?.register { request.cancel() }
        defer { removeCancellation?() }
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        try cancellation?.checkCancelled()
        return request.results?.first as? VNFeaturePrintObservation
    }

    final class VisionVideoVerifier {
        let duration: CMTime
        let durationSeconds: Double
        let generator: AVAssetImageGenerator

        init?(path: String) {
            let asset = AVURLAsset(url: URL(fileURLWithPath: path))
            let durationSeconds = CMTimeGetSeconds(asset.duration)
            guard durationSeconds.isFinite, durationSeconds > 0 else {
                return nil
            }
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            self.duration = asset.duration
            self.durationSeconds = durationSeconds
            self.generator = generator
        }
    }

    static func bestVisionFrame(
        path: String,
        requestedTime: CMTime,
        verificationTimes: [CMTime],
        queryPrints: VisionPrints,
        cancellation: VisionCancellationToken
    ) throws -> VisionFrameResult? {
        guard let verifier = VisionVideoVerifier(path: path) else { return nil }
        return try bestVisionFrame(
            verifier: verifier,
            requestedTime: requestedTime,
            verificationTimes: verificationTimes,
            queryPrints: queryPrints,
            cancellation: cancellation
        )
    }

    static func bestVisionFrame(
        verifier: VisionVideoVerifier,
        requestedTime: CMTime,
        verificationTimes: [CMTime],
        queryPrints: VisionPrints,
        cancellation: VisionCancellationToken,
        cache: VisionFramePrintCache? = nil,
        sourceFingerprint: String? = nil,
        throwOnNoFrame: Bool = false
    ) throws -> VisionFrameResult? {
        let requestedTimes = verificationTimes.isEmpty
            ? [requestedTime]
            : verificationTimes
        var best: VisionFrameResult?
        var hadValidRequest = false
        var hadUsableFrame = false
        for requestedTime in requestedTimes {
            try cancellation.checkCancelled()
            guard requestedTime.isValid,
                  !requestedTime.isIndefinite,
                  requestedTime.timescale > 0 else {
                continue
            }
            hadValidRequest = true
            let requestedSeconds = CMTimeGetSeconds(requestedTime)
            let seekTime: CMTime
            if requestedSeconds < 0 {
                seekTime = .zero
            } else if requestedSeconds > verifier.durationSeconds {
                seekTime = verifier.duration
            } else {
                seekTime = requestedTime
            }
            let cachedPrints = cache?.value(
                sourceFingerprint: sourceFingerprint ?? "",
                presentationTime: seekTime
            )
            let actualTime: CMTime
            let candidatePrints: VisionPrints
            if let cachedPrints {
                actualTime = cachedPrints.presentationTime
                candidatePrints = cachedPrints.prints
            } else {
                var generatedActualTime = CMTime.zero
                let image: CGImage?
                do {
                    let frame = try exactFrame(
                        from: verifier.generator,
                        at: seekTime,
                        cancellation: cancellation
                    )
                    image = frame?.image
                    generatedActualTime = frame?.actualTime ?? .zero
                } catch {
                    try cancellation.checkCancelled()
                    continue
                }
                guard let image else { continue }
                guard let generatedPrints = try autoreleasepool(invoking: {
                    try featurePrints(for: image, cancellation: cancellation)
                }) else { continue }
                actualTime = generatedActualTime
                candidatePrints = generatedPrints
                cache?.insert(
                    sourceFingerprint: sourceFingerprint ?? "",
                    presentationTime: actualTime,
                    prints: generatedPrints
                )
            }
            guard actualTime.isValid,
                  !actualTime.isIndefinite,
                  actualTime.timescale > 0,
                  CMTimeGetSeconds(actualTime).isFinite else {
                throw ThumbnailGenerationError.invalidPresentationTime
            }
            // A cache hit is already a successfully decoded and fingerprinted
            // frame. Mark it usable here, after validating the cached timestamp,
            // so cached-only batches do not look like unreadable videos.
            hadUsableFrame = true
            var distance = Float.greatestFiniteMagnitude
            for queryPrint in [queryPrints.full, queryPrints.centerCrop] {
                for candidatePrint in [
                    candidatePrints.full,
                    candidatePrints.centerCrop,
                ] {
                    var pairDistance: Float = 0
                    try candidatePrint.computeDistance(&pairDistance, to: queryPrint)
                    distance = min(distance, pairDistance)
                }
            }
            let actualSeconds = CMTimeGetSeconds(actualTime)
            let candidate = VisionFrameResult(
                distance: Double(distance),
                presentationTime: actualTime,
                timestampMilliseconds: Int((actualSeconds * 1000).rounded()),
                positionPercent: min(
                    max(
                        Int(
                            (actualSeconds / verifier.durationSeconds * 100).rounded()
                        ),
                        0
                    ),
                    100
                )
            )
            if best == nil || candidate.distance < best!.distance ||
                (candidate.distance == best!.distance &&
                    CMTimeCompare(candidate.presentationTime, best!.presentationTime) < 0) {
                best = candidate
            }
        }
        if throwOnNoFrame && hadValidRequest && !hadUsableFrame {
            throw ThumbnailGenerationError.decodeFailed("video frame")
        }
        return best
    }

    private static func exactFrame(
        from generator: AVAssetImageGenerator,
        at time: CMTime,
        cancellation: VisionCancellationToken
    ) throws -> (image: CGImage, actualTime: CMTime)? {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var image: CGImage?
        var actualTime = CMTime.zero
        var generationError: Error?
        var didFinish = false
        let removeCancellation = cancellation.register {
            generator.cancelAllCGImageGeneration()
            semaphore.signal()
        }
        defer { removeCancellation() }
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) {
            _, generatedImage, generatedActualTime, generationResult, error in
            lock.lock()
            guard !didFinish else {
                lock.unlock()
                return
            }
            didFinish = true
            image = generatedImage
            actualTime = generatedActualTime
            if generationResult == .cancelled {
                generationError = ThumbnailGenerationError.cancelled
            } else if let error {
                generationError = error
            }
            lock.unlock()
            semaphore.signal()
        }
        while semaphore.wait(timeout: .now() + 0.05) == .timedOut {
            try cancellation.checkCancelled()
        }
        try cancellation.checkCancelled()
        if let generationError {
            throw generationError
        }
        guard let image else { return nil }
        return (image: image, actualTime: actualTime)
    }

    static func cmTime(value: Any?, timescale: Any?) -> CMTime? {
        let rawValue: Int64?
        if let value = value as? Int64 {
            rawValue = value
        } else if let value = value as? Int {
            rawValue = Int64(value)
        } else if let value = value as? NSNumber {
            rawValue = value.int64Value
        } else {
            rawValue = nil
        }
        let rawScale: Int32?
        if let timescale = timescale as? Int32 {
            rawScale = timescale
        } else if let timescale = timescale as? Int {
            rawScale = Int32(timescale)
        } else if let timescale = timescale as? NSNumber {
            rawScale = timescale.int32Value
        } else {
            rawScale = nil
        }
        guard let rawValue, let rawScale, rawScale > 0 else {
            return nil
        }
        return CMTime(value: rawValue, timescale: rawScale)
    }
}

final class VisionCancellationToken {
    private let lock = NSLock()
    private var cancelled = false
    private var cancellationHandlers: [UUID: () -> Void] = [:]
    private let parent: VisionCancellationToken?
    private var removeParentCancellationHandler: (() -> Void)?

    init(parent: VisionCancellationToken? = nil) {
        self.parent = parent
        removeParentCancellationHandler = parent?.register { [weak self] in
            self?.cancel()
        }
    }

    deinit {
        lock.lock()
        let removeParentCancellationHandler = self.removeParentCancellationHandler
        self.removeParentCancellationHandler = nil
        lock.unlock()
        removeParentCancellationHandler?()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let handlers = Array(cancellationHandlers.values)
        cancellationHandlers.removeAll()
        let removeParentCancellationHandler = self.removeParentCancellationHandler
        self.removeParentCancellationHandler = nil
        lock.unlock()
        for handler in handlers {
            handler()
        }
        removeParentCancellationHandler?()
    }

    func checkCancelled() throws {
        lock.lock()
        let isCancelled = cancelled
        lock.unlock()
        if isCancelled || parent?.isCancelled == true {
            throw ThumbnailGenerationError.cancelled
        }
    }

    var isCancelled: Bool {
        lock.lock()
        let value = cancelled
        lock.unlock()
        return value
    }

    /// Registers work that must be interrupted when this token is cancelled.
    @discardableResult
    func register(_ handler: @escaping () -> Void) -> () -> Void {
        lock.lock()
        if cancelled {
            lock.unlock()
            handler()
            return {}
        }
        let id = UUID()
        cancellationHandlers[id] = handler
        lock.unlock()
        return { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.cancellationHandlers.removeValue(forKey: id)
            self.lock.unlock()
        }
    }
}

/// Bounded LRU cache of candidate-frame Vision observations.
final class VisionFramePrintCache {
    struct Entry {
        let sourceFingerprint: String
        let prints: ThumbnailHandler.VisionPrints
        let presentationTime: CMTime
    }

    private static let maximumCount = 128
    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private var order: [String] = []

    func value(
        sourceFingerprint: String,
        presentationTime: CMTime
    ) -> Entry? {
        let key = Self.key(
            sourceFingerprint: sourceFingerprint,
            presentationTime: presentationTime
        )
        lock.lock()
        let matchingKey: String?
        if entries[key] != nil {
            matchingKey = key
        } else {
            matchingKey = order.reversed().first { candidateKey in
                guard let entry = entries[candidateKey],
                      entry.sourceFingerprint == sourceFingerprint else {
                    return false
                }
                return CMTimeCompare(entry.presentationTime, presentationTime) == 0
            }
        }
        guard let matchingKey, let entry = entries[matchingKey] else {
            lock.unlock()
            return nil
        }
        order.removeAll { $0 == matchingKey }
        order.append(matchingKey)
        lock.unlock()
        return entry
    }

    func insert(
        sourceFingerprint: String,
        presentationTime: CMTime,
        prints: ThumbnailHandler.VisionPrints
    ) {
        let key = Self.key(
            sourceFingerprint: sourceFingerprint,
            presentationTime: presentationTime
        )
        lock.lock()
        entries[key] = Entry(
            sourceFingerprint: sourceFingerprint,
            prints: prints,
            presentationTime: presentationTime
        )
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > Self.maximumCount {
            let evicted = order.removeFirst()
            entries.removeValue(forKey: evicted)
        }
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        let value = entries.count
        lock.unlock()
        return value
    }

    private static func key(
        sourceFingerprint: String,
        presentationTime: CMTime
    ) -> String {
        "\(sourceFingerprint)|\(presentationTime.value)|\(presentationTime.timescale)|r1|full-center"
    }
}

final class VisionVerificationSession {
    let queryPrints: [String: ThumbnailHandler.VisionPrints]
    let cache = VisionFramePrintCache()
    let cancellation = VisionCancellationToken()

    init(queryPrints: [String: ThumbnailHandler.VisionPrints]) {
        self.queryPrints = queryPrints
    }

    func cancel() {
        cancellation.cancel()
    }
}

private enum ThumbnailGenerationError: LocalizedError {
    case cancelled
    case decodeFailed(String)
    case pixelBufferMissing
    case orientationFailed
    case invalidPresentationTime
    case cropFailed
    case hashFailed
    case encodeFailed
    case fileNotFound(String)
    case invalidVisionRequest

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Thumbnail generation was cancelled"
        case .decodeFailed(let path):
            return "Could not decode media at \(path)"
        case .pixelBufferMissing:
            return "A decoded video frame did not contain a pixel buffer"
        case .orientationFailed:
            return "Could not apply the video's preferred orientation"
        case .invalidPresentationTime:
            return "A decoded video frame had an invalid presentation timestamp"
        case .cropFailed:
            return "Could not create the center-crop descriptor"
        case .hashFailed:
            return "Could not create the compact frame hash"
        case .encodeFailed:
            return "Could not encode the generated thumbnail"
        case .fileNotFound(let path):
            return "Media file does not exist at \(path)"
        case .invalidVisionRequest:
            return "The Vision request was incomplete"
        }
    }
}
