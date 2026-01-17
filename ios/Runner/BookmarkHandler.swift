import Flutter
import Foundation
import UIKit
import UniformTypeIdentifiers

final class BookmarkHandler: NSObject, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
  // Keep a pending FlutterResult while the picker is presented.
  private var pendingResult: FlutterResult?

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
    case "pickDirectoryOrFiles":
      handlePickDirectoryOrFiles(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - iOS Picker Flow (session-only access)

  private func handlePickDirectoryOrFiles(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
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

    // Prefer directory picking where available; otherwise fall back to multi-file picking.
    // iOS 15+ has UTType.folder. On iOS 14, UTType is available but folder picking may be unreliable depending on providers.
    // We will attempt directory picking and if initialization fails, we’ll fall back to file picking.
    let picker: UIDocumentPickerViewController

    if #available(iOS 15.0, *) {
      // Directory mode
      picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder], asCopy: false)
      picker.allowsMultipleSelection = false
    } else {
      // Fallback to file picking with multiple selection
      if #available(iOS 14.0, *) {
        picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item], asCopy: false)
      } else {
        // Very old fallback (shouldn’t be needed with your support policy, but kept for safety)
        picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .open)
      }
      picker.allowsMultipleSelection = true
    }

    picker.delegate = self
    picker.presentationController?.delegate = self

    presenter.present(picker, animated: true, completion: nil)
  }

  // UIDocumentPickerDelegate

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pendingResult else { return }
    pendingResult = nil

    // Return file:// URL strings for practicality and clarity.
    let urlStrings = urls.map { $0.absoluteString }
    result(urlStrings)
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

  // MARK: - Bookmark APIs (macOS security-scope, iOS regular bookmarks)

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
      let bookmarkData = try url.bookmarkData(options: [],
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

      #if os(macOS)
      let started = url.startAccessingSecurityScopedResource()
      if !started {
        result(FlutterError(code: "BOOKMARK_ACCESS",
                            message: "Failed to start accessing bookmark",
                            details: nil))
        return
      }
      #endif

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
      #if os(macOS)
      let url = try URL(resolvingBookmarkData: bookmarkData,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale)
      if !isStale {
        url.stopAccessingSecurityScopedResource()
      }
      #else
      _ = try URL(resolvingBookmarkData: bookmarkData,
                  options: [],
                  relativeTo: nil,
                  bookmarkDataIsStale: &isStale)
      #endif
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
