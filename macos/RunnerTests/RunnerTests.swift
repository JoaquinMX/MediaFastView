import Cocoa
import FlutterMacOS
import XCTest

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
}
