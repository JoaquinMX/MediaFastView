import Flutter
import UIKit
import UniformTypeIdentifiers

class BookmarkHandler: NSObject {
  private weak var viewController: FlutterViewController?
  private var pendingResult: FlutterResult?

  init(viewController: FlutterViewController?) {
    self.viewController = viewController
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "createBookmark":
      handleCreateBookmark(call, result: result)
    case "selectDirectoryAndCreateBookmark":
      handleSelectDirectoryAndCreateBookmark(call, result: result)
    case "resolveBookmark":
      handleResolveBookmark(call, result: result)
    case "isBookmarkValid":
      handleIsBookmarkValid(call, result: result)
    case "startAccessingBookmark":
      handleStartAccessingBookmark(call, result: result)
    case "stopAccessingBookmark":
      handleStopAccessingBookmark(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleCreateBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let directoryPath = args["directoryPath"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS",
                          message: "Directory path is required",
                          details: nil))
      return
    }

    do {
      let bookmarkData = try createBookmark(for: directoryPath)
      result(bookmarkData.base64EncodedString())
    } catch {
      result(FlutterError(code: "BOOKMARK_CREATION_FAILED",
                          message: "Failed to create bookmark: \(error.localizedDescription)",
                          details: nil))
    }
  }

  private func handleSelectDirectoryAndCreateBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard pendingResult == nil else {
      result(FlutterError(code: "PICKER_BUSY",
                          message: "Another directory selection is in progress",
                          details: nil))
      return
    }

    let args = call.arguments as? [String: Any]
    let initialDirectoryPath = args?["initialDirectoryPath"] as? String

    presentDirectoryPicker(initialDirectoryPath: initialDirectoryPath, result: result)
  }

  private func handleResolveBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let bookmarkDataString = args["bookmarkData"] as? String,
          let bookmarkData = Data(base64Encoded: bookmarkDataString) else {
      result(FlutterError(code: "INVALID_ARGUMENTS",
                          message: "Bookmark data is required",
                          details: nil))
      return
    }

    do {
      var isStale = false
      let url = try URL(resolvingBookmarkData: bookmarkData,
                        options: [.withSecurityScope],
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale)
      result(url.path)
    } catch {
      result(FlutterError(code: "BOOKMARK_RESOLUTION_FAILED",
                          message: "Failed to resolve bookmark: \(error.localizedDescription)",
                          details: nil))
    }
  }

  private func handleStartAccessingBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let bookmarkDataString = args["bookmarkData"] as? String,
          let bookmarkData = Data(base64Encoded: bookmarkDataString) else {
      result(FlutterError(code: "INVALID_ARGUMENTS",
                          message: "Bookmark data is required",
                          details: nil))
      return
    }

    do {
      var isStale = false
      let url = try URL(resolvingBookmarkData: bookmarkData,
                        options: [.withSecurityScope],
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale)

      guard url.startAccessingSecurityScopedResource() else {
        result(FlutterError(code: "START_ACCESS_FAILED",
                            message: "Could not start accessing security scoped resource",
                            details: nil))
        return
      }

      result(url.path)
    } catch {
      result(FlutterError(code: "START_ACCESS_FAILED",
                          message: "Failed to start accessing bookmark: \(error.localizedDescription)",
                          details: nil))
    }
  }

  private func handleStopAccessingBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let bookmarkDataString = args["bookmarkData"] as? String,
          let bookmarkData = Data(base64Encoded: bookmarkDataString) else {
      result(FlutterError(code: "INVALID_ARGUMENTS",
                          message: "Bookmark data is required",
                          details: nil))
      return
    }

    do {
      var isStale = false
      let url = try URL(resolvingBookmarkData: bookmarkData,
                        options: [.withSecurityScope],
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale)
      url.stopAccessingSecurityScopedResource()
      result(nil)
    } catch {
      result(FlutterError(code: "STOP_ACCESS_FAILED",
                          message: "Failed to stop accessing bookmark: \(error.localizedDescription)",
                          details: nil))
    }
  }

  private func handleIsBookmarkValid(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let bookmarkDataString = args["bookmarkData"] as? String,
          let bookmarkData = Data(base64Encoded: bookmarkDataString) else {
      result(false)
      return
    }

    do {
      var isStale = false
      _ = try URL(resolvingBookmarkData: bookmarkData,
                  options: [.withSecurityScope],
                  relativeTo: nil,
                  bookmarkDataIsStale: &isStale)
      result(!isStale)
    } catch {
      result(false)
    }
  }

  private func createBookmark(for directoryPath: String) throws -> Data {
    let url = URL(fileURLWithPath: directoryPath)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      throw NSError(domain: "BookmarkHandler",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Directory does not exist or is not a directory"])
    }

    return try url.bookmarkData(options: .withSecurityScope,
                                includingResourceValuesForKeys: nil,
                                relativeTo: nil)
  }

  private func presentDirectoryPicker(initialDirectoryPath: String?, result: @escaping FlutterResult) {
    guard let controller = viewController else {
      result(FlutterError(code: "NO_VIEW_CONTROLLER",
                          message: "Unable to access root view controller",
                          details: nil))
      return
    }

    pendingResult = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
    picker.delegate = self
    picker.allowsMultipleSelection = false
    picker.directoryURL = initialDirectoryPath != nil ? URL(fileURLWithPath: initialDirectoryPath!) : nil
    controller.present(picker, animated: true)
  }
}

extension BookmarkHandler: UIDocumentPickerDelegate {
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingResult?(FlutterError(code: "USER_CANCELLED",
                                message: "User cancelled directory selection",
                                details: nil))
    pendingResult = nil
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first else {
      pendingResult?(FlutterError(code: "NO_DIRECTORY",
                                  message: "No directory selected",
                                  details: nil))
      pendingResult = nil
      return
    }

    let accessStarted = url.startAccessingSecurityScopedResource()
    defer { if accessStarted { url.stopAccessingSecurityScopedResource() } }

    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      pendingResult?(FlutterError(code: "INVALID_SELECTION",
                                  message: "Selected item is not a directory",
                                  details: nil))
      pendingResult = nil
      return
    }

    do {
      let bookmarkData = try url.bookmarkData(options: .withSecurityScope,
                                              includingResourceValuesForKeys: nil,
                                              relativeTo: nil)
      pendingResult?([
        "directoryPath": url.path,
        "bookmarkData": bookmarkData.base64EncodedString(),
      ])
    } catch {
      pendingResult?(FlutterError(code: "BOOKMARK_CREATION_FAILED",
                                  message: "Failed to create bookmark: \(error.localizedDescription)",
                                  details: nil))
    }

    pendingResult = nil
  }
}
