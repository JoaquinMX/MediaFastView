import FlutterMacOS
import Foundation

class BookmarkHandler: NSObject {
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
            logError("Invalid arguments for createBookmark")
            result(FlutterError(code: "INVALID_ARGUMENTS",
                               message: "Directory path is required",
                               details: nil))
            return
        }

        do {
            let bookmarkData = try createBookmark(for: directoryPath)
            let base64String = bookmarkData.base64EncodedString()
            logInfo("Successfully created bookmark for path: \(directoryPath)")
            result(base64String)
        } catch {
            logError("Failed to create bookmark for path \(directoryPath): \(error)")
            result(FlutterError(code: "BOOKMARK_CREATION_FAILED",
                               message: "Failed to create bookmark: \(error.localizedDescription)",
                               details: nil))
        }
    }

    private func handleSelectDirectoryAndCreateBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let initialDirectoryPath = args?["initialDirectoryPath"] as? String

        do {
            let resultData = try selectDirectoryAndCreateBookmark(initialDirectoryPath: initialDirectoryPath)
            logInfo("Successfully selected directory and created bookmark")
            result(resultData)
        } catch {
            logError("Failed to select directory and create bookmark: \(error)")
            result(FlutterError(code: "DIRECTORY_SELECTION_FAILED",
                               message: "Failed to select directory and create bookmark: \(error.localizedDescription)",
                               details: nil))
        }
    }

    private func handleResolveBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let bookmarkDataString = args["bookmarkData"] as? String else {
            logError("Invalid arguments for resolveBookmark")
            result(FlutterError(code: "INVALID_ARGUMENTS",
                               message: "Bookmark data is required",
                               details: nil))
            return
        }

        guard let bookmarkData = Data(base64Encoded: bookmarkDataString) else {
            logError("Invalid base64 bookmark data")
            result(FlutterError(code: "INVALID_BOOKMARK_DATA",
                               message: "Bookmark data is not valid base64",
                               details: nil))
            return
        }

        do {
            let resolvedPath = try resolveBookmark(from: bookmarkData)
            logInfo("Successfully resolved bookmark to path: \(resolvedPath)")
            result(resolvedPath)
        } catch {
            logError("Failed to resolve bookmark: \(error)")
            result(FlutterError(code: "BOOKMARK_RESOLUTION_FAILED",
                               message: "Failed to resolve bookmark: \(error.localizedDescription)",
                               details: nil))
        }
    }

    private func handleStartAccessingBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let bookmarkDataString = args["bookmarkData"] as? String else {
            logError("Invalid arguments for startAccessingBookmark")
            result(FlutterError(code: "INVALID_ARGUMENTS",
                               message: "Bookmark data is required",
                               details: nil))
            return
        }

        guard let bookmarkData = Data(base64Encoded: bookmarkDataString) else {
            logError("Invalid base64 bookmark data")
            result(FlutterError(code: "INVALID_BOOKMARK_DATA",
                               message: "Bookmark data is not valid base64",
                               details: nil))
            return
        }

        do {
            let resolvedPath = try startAccessingBookmark(bookmarkData)
            logInfo("Successfully started accessing bookmark at path: \(resolvedPath)")
            result(resolvedPath)
        } catch {
            logError("Failed to start accessing bookmark: \(error)")
            result(FlutterError(code: "START_ACCESS_FAILED",
                               message: "Failed to start accessing bookmark: \(error.localizedDescription)",
                               details: nil))
        }
    }

    private func handleStopAccessingBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let bookmarkDataString = args["bookmarkData"] as? String else {
            logError("Invalid arguments for stopAccessingBookmark")
            result(FlutterError(code: "INVALID_ARGUMENTS",
                               message: "Bookmark data is required",
                               details: nil))
            return
        }

        guard let bookmarkData = Data(base64Encoded: bookmarkDataString) else {
            logError("Invalid base64 bookmark data")
            result(FlutterError(code: "INVALID_BOOKMARK_DATA",
                               message: "Bookmark data is not valid base64",
                               details: nil))
            return
        }

        do {
            try stopAccessingBookmark(bookmarkData)
            logInfo("Successfully stopped accessing bookmark")
            result(nil)
        } catch {
            logError("Failed to stop accessing bookmark: \(error)")
            result(FlutterError(code: "STOP_ACCESS_FAILED",
                               message: "Failed to stop accessing bookmark: \(error.localizedDescription)",
                               details: nil))
        }
    }

    private func handleIsBookmarkValid(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let bookmarkDataString = args["bookmarkData"] as? String else {
            logError("Invalid arguments for isBookmarkValid")
            result(FlutterError(code: "INVALID_ARGUMENTS",
                              message: "Bookmark data is required",
                              details: nil))
            return
        }

        guard let bookmarkData = Data(base64Encoded: bookmarkDataString) else {
            logError("Invalid base64 bookmark data")
            result(false)
            return
        }

        do {
            let isValid = try isBookmarkValid(bookmarkData)
            logInfo("Bookmark validation result: \(isValid)")
            result(isValid)
        } catch {
            logError("Error checking bookmark validity: \(error)")
            result(false)
        }
    }

    private func createBookmark(for directoryPath: String) throws -> Data {
        let url = URL(fileURLWithPath: directoryPath)

        // Check if the directory exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw NSError(domain: "BookmarkHandler",
                          code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Directory does not exist or is not a directory"])
        }

        // Create security-scoped bookmark
        let bookmarkData = try url.bookmarkData(options: .withSecurityScope,
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil)
        return bookmarkData
    }

    private func selectDirectoryAndCreateBookmark(initialDirectoryPath: String?) throws -> [String: Any] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a directory to grant access"
        panel.prompt = "Select"

        // Set initial directory if provided
        if let initialPath = initialDirectoryPath {
            let initialURL = URL(fileURLWithPath: initialPath)
            panel.directoryURL = initialURL
        }

        // Run the panel
        let response = panel.runModal()
        guard response == .OK, let selectedURL = panel.url else {
            throw NSError(domain: "BookmarkHandler",
                          code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "User cancelled directory selection or no directory selected"])
        }

        // Verify it's a directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: selectedURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw NSError(domain: "BookmarkHandler",
                          code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Selected item is not a directory"])
        }

        // Create security-scoped bookmark from the selected URL
        let bookmarkData = try selectedURL.bookmarkData(options: .withSecurityScope,
                                                        includingResourceValuesForKeys: nil,
                                                        relativeTo: nil)

        let base64String = bookmarkData.base64EncodedString()

        return [
            "directoryPath": selectedURL.path,
            "bookmarkData": base64String
        ]
    }

    private func resolveBookmark(from bookmarkData: Data) throws -> String {
        var isStale = false
        let url = try URL(resolvingBookmarkData: bookmarkData,
                           options: .withSecurityScope,
                           relativeTo: nil,
                           bookmarkDataIsStale: &isStale)

        if isStale {
            logError("CRITICAL: Resolved bookmark is stale - this indicates bookmark expiration")
        }

        return url.path
    }

    private func isBookmarkValid(_ bookmarkData: Data) throws -> Bool {
        var isStale = false
        do {
            _ = try URL(resolvingBookmarkData: bookmarkData,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale)
            return !isStale
        } catch {
            return false
        }
    }

    private func startAccessingBookmark(_ bookmarkData: Data) throws -> String {
        var isStale = false
        let url = try URL(resolvingBookmarkData: bookmarkData,
                          options: .withSecurityScope,
                          relativeTo: nil,
                          bookmarkDataIsStale: &isStale)

        if isStale {
            logWarning("Resolved bookmark is stale")
        }

        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "BookmarkHandler",
                          code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to start accessing security-scoped resource"])
        }

        return url.path
    }

    private func stopAccessingBookmark(_ bookmarkData: Data) throws {
        var isStale = false
        let url = try URL(resolvingBookmarkData: bookmarkData,
                          options: .withSecurityScope,
                          relativeTo: nil,
                          bookmarkDataIsStale: &isStale)

        if isStale {
            logWarning("Bookmark is stale when stopping access")
        }

        url.stopAccessingSecurityScopedResource()
    }

    private func logInfo(_ message: String) {
        print("[BookmarkHandler] INFO: \(message)")
    }

    private func logWarning(_ message: String) {
        print("[BookmarkHandler] WARNING: \(message)")
    }

    private func logError(_ message: String) {
        print("[BookmarkHandler] ERROR: \(message)")
    }
}