import Flutter
import Foundation
import UIKit

final class BookmarkHandler {
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
    guard
      let args = call.arguments as? [String: Any],
      let directoryPath = args["directoryPath"] as? String
    else {
      result(FlutterError(code: "INVALID_ARGUMENTS",
                          message: "Missing directoryPath argument",
                          details: nil))
      return
    }

    let url = URL(fileURLWithPath: directoryPath)

    do {
      let bookmarkData = try url.bookmarkData(options: .withSecurityScope,
                                              includingResourceValuesForKeys: nil,
                                              relativeTo: nil)
      let base64String = bookmarkData.base64EncodedString()
      result(base64String)
    } catch {
      result(FlutterError(code: "BOOKMARK_ERROR",
                          message: "Failed to create bookmark: \(error.localizedDescription)",
                          details: nil))
    }
  }

  private func handleResolveBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let bookmarkDataString = args["bookmarkData"] as? String,
      let bookmarkData = Data(base64Encoded: bookmarkDataString)
    else {
      result(FlutterError(code: "INVALID_ARGUMENTS",
                          message: "Missing bookmarkData argument",
                          details: nil))
      return
    }

    var isStale = false
    do {
      let url = try URL(resolvingBookmarkData: bookmarkData,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale)
      if isStale {
        result(FlutterError(code: "BOOKMARK_STALE",
                            message: "Bookmark data is stale",
                            details: nil))
        return
      }
      result(url.path)
    } catch {
      result(FlutterError(code: "BOOKMARK_ERROR",
                          message: "Failed to resolve bookmark: \(error.localizedDescription)",
                          details: nil))
    }
  }

  private func handleStartAccessingBookmark(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard
      let args = call.arguments as? [String: Any],
      let bookmarkDataString = args["bookmarkData"] as? String,
      let bookmarkData = Data(base64Encoded: bookmarkDataString)
    else {
      result(FlutterError(code: "INVALID_ARGUMENTS",
                          message: "Missing bookmarkData argument",
                          details: nil))
      return
    }

    var isStale = false
    do {
      let url = try URL(resolvingBookmarkData: bookmarkData,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale)
      if isStale {
        result(FlutterError(code: "BOOKMARK_STALE",
                            message: "Bookmark data is stale",
                            details: nil))
        return
      }

      let started = url.startAccessingSecurityScopedResource()
      if !started {
        result(FlutterError(code: "BOOKMARK_ACCESS",
                            message: "Failed to start accessing bookmark",
                            details: nil))
        return
      }

      result(url.path)
    } catch {
      result(FlutterError(code: "BOOKMARK_ERROR",
                          message: "Failed to start accessing bookmark: \(error.localizedDescription)",
                          details: nil))
    }
  }

  private func handleStopAccessingBookmark(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard
      let args = call.arguments as? [String: Any],
      let bookmarkDataString = args["bookmarkData"] as? String,
      let bookmarkData = Data(base64Encoded: bookmarkDataString)
    else {
      result(FlutterError(code: "INVALID_ARGUMENTS",
                          message: "Missing bookmarkData argument",
                          details: nil))
      return
    }

    var isStale = false
    do {
      let url = try URL(resolvingBookmarkData: bookmarkData,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale)
      if !isStale {
        url.stopAccessingSecurityScopedResource()
      }
      result(nil)
    } catch {
      result(FlutterError(code: "BOOKMARK_ERROR",
                          message: "Failed to stop accessing bookmark: \(error.localizedDescription)",
                          details: nil))
    }
  }

  private func handleIsBookmarkValid(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let bookmarkDataString = args["bookmarkData"] as? String,
      let bookmarkData = Data(base64Encoded: bookmarkDataString)
    else {
      result(false)
      return
    }

    var isStale = false
    do {
      _ = try URL(resolvingBookmarkData: bookmarkData,
                  options: .withSecurityScope,
                  relativeTo: nil,
                  bookmarkDataIsStale: &isStale)
      result(!isStale)
    } catch {
      result(false)
    }
  }
}
