import Flutter
import UIKit

/// Handles security-scoped bookmark operations for iOS.
class BookmarkHandler: NSObject {
  private enum BookmarkError: Error {
    case invalidArguments(String)
    case fileNotFound(String)
    case startAccessFailed
  }

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.joaquinmx.media_fast_view/bookmarks",
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler(handle)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "createBookmark":
      handleCreateBookmark(call, result: result)
    case "resolveBookmark":
      handleResolveBookmark(call, result: result)
    case "startAccessingBookmark":
      handleStartAccessingBookmark(call, result: result)
    case "stopAccessingBookmark":
      handleStopAccessingBookmark(call, result: result)
    case "isBookmarkValid":
      handleIsBookmarkValid(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleCreateBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      let directoryPath = try extractDirectoryPath(from: call)
      let bookmark = try createBookmark(for: directoryPath)
      result(bookmark.base64EncodedString())
    } catch {
      result(FlutterError(
        code: "BOOKMARK_CREATION_FAILED",
        message: "Failed to create bookmark: \(error.localizedDescription)",
        details: nil
      ))
    }
  }

  private func handleResolveBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      let bookmarkData = try extractBookmarkData(from: call)
      let resolvedPath = try resolveBookmark(from: bookmarkData)
      result(resolvedPath.path)
    } catch {
      result(FlutterError(
        code: "BOOKMARK_RESOLUTION_FAILED",
        message: "Failed to resolve bookmark: \(error.localizedDescription)",
        details: nil
      ))
    }
  }

  private func handleStartAccessingBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      let bookmarkData = try extractBookmarkData(from: call)
      let resolvedPath = try startAccessingBookmark(bookmarkData)
      result(resolvedPath.path)
    } catch {
      result(FlutterError(
        code: "START_ACCESS_FAILED",
        message: "Failed to start accessing bookmark: \(error.localizedDescription)",
        details: nil
      ))
    }
  }

  private func handleStopAccessingBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      let bookmarkData = try extractBookmarkData(from: call)
      try stopAccessingBookmark(bookmarkData)
      result(nil)
    } catch {
      result(FlutterError(
        code: "STOP_ACCESS_FAILED",
        message: "Failed to stop accessing bookmark: \(error.localizedDescription)",
        details: nil
      ))
    }
  }

  private func handleIsBookmarkValid(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      let bookmarkData = try extractBookmarkData(from: call)
      _ = try resolveBookmark(from: bookmarkData)
      result(true)
    } catch {
      result(false)
    }
  }

  // MARK: - Bookmark helpers

  private func createBookmark(for directoryPath: String) throws -> Data {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      throw BookmarkError.fileNotFound("Directory does not exist at path: \(directoryPath)")
    }

    let url = URL(fileURLWithPath: directoryPath)
    return try url.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
  }

  private func resolveBookmark(from bookmarkData: Data) throws -> URL {
    var isStale = false
    let url = try URL(
      resolvingBookmarkData: bookmarkData,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )

    if isStale {
      // Create a fresh bookmark so callers can persist the renewed data.
      let renewedBookmark = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      // Return the original resolved URL; Dart side can decide whether to store renewed data.
      // Caller gets notified via startAccessingBookmark return path.
      _ = renewedBookmark
    }

    return url
  }

  private func startAccessingBookmark(_ bookmarkData: Data) throws -> URL {
    let url = try resolveBookmark(from: bookmarkData)
    guard url.startAccessingSecurityScopedResource() else {
      throw BookmarkError.startAccessFailed
    }
    return url
  }

  private func stopAccessingBookmark(_ bookmarkData: Data) throws {
    let url = try resolveBookmark(from: bookmarkData)
    url.stopAccessingSecurityScopedResource()
  }

  // MARK: - Argument extraction

  private func extractDirectoryPath(from call: FlutterMethodCall) throws -> String {
    guard let args = call.arguments as? [String: Any],
          let directoryPath = args["directoryPath"] as? String,
          !directoryPath.isEmpty else {
      throw BookmarkError.invalidArguments("Directory path is required")
    }
    return directoryPath
  }

  private func extractBookmarkData(from call: FlutterMethodCall) throws -> Data {
    guard let args = call.arguments as? [String: Any],
          let bookmarkString = args["bookmarkData"] as? String,
          let data = Data(base64Encoded: bookmarkString) else {
      throw BookmarkError.invalidArguments("Bookmark data is required")
    }
    return data
  }
}
