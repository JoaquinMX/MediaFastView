import Flutter
import Foundation
import UIKit
import UniformTypeIdentifiers

final class BookmarkHandler: NSObject, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
  private struct ScopedResourceAccess {
    let url: URL
    var referenceCount: Int
  }

  // Keep a pending FlutterResult while the picker is presented.
  private var pendingResult: FlutterResult?
  private var activeBookmarkAccess = [String: ScopedResourceAccess]()

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
    case "pickDirectories":
      handlePickDirectories(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - iOS Picker Flow

  private func handlePickDirectories(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Prevent multiple concurrent pickers.
    if pendingResult != nil {
      result(FlutterError(code: "PICKER_BUSY",
                          message: "Another picker is already active.",
                          details: nil))
      return
    }
    guard let presenter = topMostViewController() else {
      result(FlutterError(code: "NO_PRESENTER",
                          message: "Unable to find a view controller to present from.",
                          details: nil))
      return
    }

    pendingResult = result

    let arguments = call.arguments as? [String: Any]
    let allowsMultipleSelection = arguments?["allowsMultipleSelection"] as? Bool ?? false
    let picker = makeDirectoryPicker(
      allowsMultipleSelection: allowsMultipleSelection
    )

    picker.delegate = self
    picker.presentationController?.delegate = self

    presenter.present(picker, animated: true, completion: nil)
  }

  func makeDirectoryPicker(
    allowsMultipleSelection: Bool
  ) -> UIDocumentPickerViewController {
    let picker = UIDocumentPickerViewController(
      forOpeningContentTypes: [UTType.folder],
      asCopy: false
    )
    picker.allowsMultipleSelection = allowsMultipleSelection
    return picker
  }

  // UIDocumentPickerDelegate

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pendingResult else { return }
    pendingResult = nil

    do {
      result(try pickedDirectoryPayloads(from: urls))
    } catch {
      result(FlutterError(
        code: "BOOKMARK_ERROR",
        message: "Failed to preserve access to the selected directories: \(error.localizedDescription)",
        details: nil
      ))
    }
  }

  func pickedDirectoryPayloads(from urls: [URL]) throws -> [[String: String]] {
    try urls.map { originalUrl in
      let url = originalUrl.standardizedFileURL
      let startedAccess = url.startAccessingSecurityScopedResource()
      defer {
        if startedAccess {
          url.stopAccessingSecurityScopedResource()
        }
      }

      let bookmarkData = try url.bookmarkData(
        options: .minimalBookmark,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      return [
        "url": url.absoluteString,
        "bookmarkData": bookmarkData.base64EncodedString(),
      ]
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard let result = pendingResult else { return }
    pendingResult = nil
    // Return empty array to indicate no selection.
    result([String]())
  }

  // In case the sheet is dismissed by system gestures on iOS 13+
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    guard let result = pendingResult else { return }
    pendingResult = nil
    result([String]())
  }

  // Helper to find the top-most view controller for presentation.
  private func topMostViewController(from base: UIViewController? = UIApplication.shared.connectedScenes
    .compactMap { ($0 as? UIWindowScene)?.keyWindow }
    .first?.rootViewController) -> UIViewController? {

    guard let base = base else { return nil }
    if let nav = base as? UINavigationController {
      return topMostViewController(from: nav.visibleViewController)
    }
    if let tab = base as? UITabBarController {
      return topMostViewController(from: tab.selectedViewController)
    }
    if let presented = base.presentedViewController {
      return topMostViewController(from: presented)
    }
    return base
  }

  deinit {
    for access in activeBookmarkAccess.values {
      access.url.stopAccessingSecurityScopedResource()
    }
    activeBookmarkAccess.removeAll()
  }

  // MARK: - Apple Security-Scoped Bookmark APIs

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
      #if os(macOS)
      let bookmarkData = try url.bookmarkData(options: .withSecurityScope,
                                              includingResourceValuesForKeys: nil,
                                              relativeTo: nil)
      #else
      let bookmarkData = try url.bookmarkData(options: .minimalBookmark,
                                              includingResourceValuesForKeys: nil,
                                              relativeTo: nil)
      #endif
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
      #if os(macOS)
      let url = try URL(resolvingBookmarkData: bookmarkData,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale)
      #else
      let url = try URL(resolvingBookmarkData: bookmarkData,
                        options: [],
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale)
      #endif
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
      #if os(macOS)
      let url = try URL(resolvingBookmarkData: bookmarkData,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale)
      #else
      let url = try URL(resolvingBookmarkData: bookmarkData,
                        options: [],
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale)
      #endif
      if isStale {
        result(FlutterError(code: "BOOKMARK_STALE",
                            message: "Bookmark data is stale",
                            details: nil))
        return
      }

      if var activeAccess = activeBookmarkAccess[bookmarkDataString] {
        activeAccess.referenceCount += 1
        activeBookmarkAccess[bookmarkDataString] = activeAccess
        result(activeAccess.url.path)
        return
      }

      let started = url.startAccessingSecurityScopedResource()
      if !started {
        result(FlutterError(code: "BOOKMARK_ACCESS",
                            message: "Failed to start accessing bookmark",
                            details: nil))
        return
      }

      activeBookmarkAccess[bookmarkDataString] = ScopedResourceAccess(
        url: url,
        referenceCount: 1
      )

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
      Data(base64Encoded: bookmarkDataString) != nil
    else {
      result(FlutterError(code: "INVALID_ARGUMENTS",
                          message: "Missing bookmarkData argument",
                          details: nil))
      return
    }

    guard var activeAccess = activeBookmarkAccess[bookmarkDataString] else {
      result(nil)
      return
    }

    activeAccess.referenceCount -= 1
    if activeAccess.referenceCount <= 0 {
      activeAccess.url.stopAccessingSecurityScopedResource()
      activeBookmarkAccess.removeValue(forKey: bookmarkDataString)
    } else {
      activeBookmarkAccess[bookmarkDataString] = activeAccess
    }
    result(nil)
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
      #if os(macOS)
      _ = try URL(resolvingBookmarkData: bookmarkData,
                  options: .withSecurityScope,
                  relativeTo: nil,
                  bookmarkDataIsStale: &isStale)
      #else
      _ = try URL(resolvingBookmarkData: bookmarkData,
                  options: [],
                  relativeTo: nil,
                  bookmarkDataIsStale: &isStale)
      #endif
      result(!isStale)
    } catch {
      result(false)
    }
  }
}
