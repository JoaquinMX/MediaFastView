import Flutter
import UIKit
import XCTest

@testable import Runner

final class RunnerTests: XCTestCase {
  func testDirectoryPickerAllowsMultipleSelectionWhenRequested() {
    let picker = BookmarkHandler().makeDirectoryPicker(
      allowsMultipleSelection: true
    )

    XCTAssertTrue(picker.allowsMultipleSelection)
  }

  func testDirectoryPickerKeepsRecoverySingleSelection() {
    let picker = BookmarkHandler().makeDirectoryPicker(
      allowsMultipleSelection: false
    )

    XCTAssertFalse(picker.allowsMultipleSelection)
  }

  func testPickedDirectoryPayloadsPreserveEverySelectionInOrder() throws {
    let handler = BookmarkHandler()
    let testRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let first = testRoot.appendingPathComponent("first", isDirectory: true)
    let second = testRoot.appendingPathComponent("second", isDirectory: true)
    try FileManager.default.createDirectory(
      at: first,
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: second,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: testRoot) }

    let payloads = try handler.pickedDirectoryPayloads(from: [first, second])

    XCTAssertEqual(
      payloads.map { $0["url"] },
      [first.absoluteString, second.absoluteString]
    )
    XCTAssertTrue(payloads.allSatisfy { $0["bookmarkData"]?.isEmpty == false })
  }
}
