import FlutterMacOS
import Foundation

/// Holds one or more security-scoped resource accesses for the duration of a
/// sandboxed file operation.
///
/// A transfer between two directories needs *two* scopes held at once — the
/// source root's bookmark and the destination root's — which is why this is a
/// collection rather than the single `URL` that `moveToTrash` used to keep.
private final class ScopedAccess {
    private var accessed: [URL] = []

    /// Resolves `bookmarkBase64` and starts security-scoped access to it.
    ///
    /// Deliberately tolerant: a resolution or start failure is logged and the
    /// caller proceeds anyway, because the operation can still succeed for a
    /// path the process can already reach.
    func begin(_ bookmarkBase64: String?, label: String, log: (String) -> Void) {
        guard let bookmarkBase64,
              let data = Data(base64Encoded: bookmarkBase64) else { return }

        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: data,
                              options: .withSecurityScope,
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            if isStale {
                log("The \(label) bookmark is stale")
            }
            // A transfer within one library root resolves the same URL twice;
            // starting it twice would need two stops to balance.
            guard !accessed.contains(where: { $0.path == url.path }) else { return }

            if url.startAccessingSecurityScopedResource() {
                accessed.append(url)
            } else {
                log("Failed to start accessing the \(label) bookmark; attempting anyway")
            }
        } catch {
            log("Failed to resolve the \(label) bookmark: \(error); attempting anyway")
        }
    }

    func endAll() {
        for url in accessed.reversed() {
            url.stopAccessingSecurityScopedResource()
        }
        accessed.removeAll()
    }
}

private enum TransferKind {
    case move
    case copy

    var verb: String {
        switch self {
        case .move: return "Move"
        case .copy: return "Copy"
        }
    }

    var failureCode: String {
        switch self {
        case .move: return "MOVE_FAILED"
        case .copy: return "COPY_FAILED"
        }
    }
}

private enum TransferOutcome {
    case success([String: Any])
    case failure(FlutterError)
}

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
        case "moveToTrash":
            handleMoveToTrash(call, result: result)
        case "moveItem":
            handleTransfer(call, kind: .move, result: result)
        case "copyItem":
            handleTransfer(call, kind: .copy, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Transfer (move / copy)

    /// Moves or copies an item between directories inside security-scoped access
    /// to both the source and the destination.
    private func handleTransfer(_ call: FlutterMethodCall, kind: TransferKind, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let sourcePath = args["sourcePath"] as? String,
              let destinationPath = args["destinationPath"] as? String else {
            logError("Invalid arguments for \(kind.verb.lowercased())Item")
            result(FlutterError(code: "INVALID_ARGUMENTS",
                               message: "sourcePath and destinationPath are required",
                               details: nil))
            return
        }

        let sourceBookmark = args["sourceBookmarkData"] as? String
        let destinationBookmark = args["destinationBookmarkData"] as? String
        let keepBoth = (args["conflictStrategy"] as? String) == "keepBoth"

        // A cross-volume transfer copies every byte, which for a large video can
        // take many seconds. Running that on the platform thread would freeze the
        // whole UI, so unlike moveToTrash this is dispatched off it.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let scopes = ScopedAccess()
            defer { scopes.endAll() }
            scopes.begin(sourceBookmark, label: "source") { self.logWarning($0) }
            scopes.begin(destinationBookmark, label: "destination") { self.logWarning($0) }

            let outcome = self.performTransfer(kind: kind,
                                               sourcePath: sourcePath,
                                               destinationPath: destinationPath,
                                               keepBoth: keepBoth)

            DispatchQueue.main.async {
                switch outcome {
                case .success(let payload):
                    result(payload)
                case .failure(let error):
                    result(error)
                }
            }
        }
    }

    private func performTransfer(kind: TransferKind,
                                 sourcePath: String,
                                 destinationPath: String,
                                 keepBoth: Bool) -> TransferOutcome {
        let fileManager = FileManager.default

        // Resolve symlinks on both sides so the containment checks below compare
        // real locations — a descendant reached through a link would otherwise
        // slip past them.
        let source = URL(fileURLWithPath: sourcePath).standardizedFileURL.resolvingSymlinksInPath()
        let requestedDestination = URL(fileURLWithPath: destinationPath).standardizedFileURL
        let destinationParent = requestedDestination.deletingLastPathComponent().resolvingSymlinksInPath()
        var destination = destinationParent.appendingPathComponent(requestedDestination.lastPathComponent)

        var sourceIsDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &sourceIsDirectory) else {
            return .failure(FlutterError(code: "SOURCE_NOT_FOUND",
                                        message: "The item no longer exists: \(source.path)",
                                        details: nil))
        }

        var parentIsDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destinationParent.path, isDirectory: &parentIsDirectory),
              parentIsDirectory.boolValue else {
            return .failure(FlutterError(code: "DESTINATION_PARENT_NOT_FOUND",
                                        message: "The destination folder does not exist: \(destinationParent.path)",
                                        details: nil))
        }

        guard destination.path != source.path else {
            return .failure(FlutterError(code: "SAME_PATH",
                                        message: "The item is already in that folder",
                                        details: nil))
        }

        if sourceIsDirectory.boolValue,
           destination.path.hasPrefix(source.path + "/") {
            return .failure(FlutterError(code: "DESTINATION_INSIDE_SOURCE",
                                        message: "A folder cannot be moved into itself or one of its subfolders",
                                        details: nil))
        }

        // Collision handling lives here rather than in Dart: only this call holds
        // the security scope needed to probe the destination, and any Dart-side
        // probe would race the transfer itself. `fileExists` also honours the
        // volume's case-folding, so photo.JPG vs photo.jpg collides correctly on
        // APFS/HFS+ for free.
        var renamed = false
        if fileManager.fileExists(atPath: destination.path) {
            let suggestion = uniqueDestination(for: destination)

            guard keepBoth else {
                return .failure(FlutterError(
                    code: "DESTINATION_EXISTS",
                    message: "An item named \"\(destination.lastPathComponent)\" already exists in that folder",
                    details: [
                        "destinationPath": destination.path,
                        "suggestedPath": (suggestion ?? destination).path,
                    ]))
            }

            guard let suggestion else {
                return .failure(FlutterError(
                    code: "NAME_COLLISION_UNRESOLVED",
                    message: "Could not find an unused name for \"\(destination.lastPathComponent)\"",
                    details: nil))
            }

            destination = suggestion
            renamed = true
        }

        let sameVolume = isSameVolume(source, destinationParent)

        do {
            switch kind {
            case .move:
                try fileManager.moveItem(at: source, to: destination)
            case .copy:
                try fileManager.copyItem(at: source, to: destination)
                // copyItem preserves the modification date. Media ids are
                // sha256(size_mtime_name), so without a fresh stamp the copy
                // would hash to its source's id and overwrite the source's row
                // in the cache.
                try? fileManager.setAttributes([.modificationDate: Date()],
                                               ofItemAtPath: destination.path)
            }
        } catch {
            logError("\(kind.verb) failed \(source.path) -> \(destination.path): \(error)")
            return .failure(transferError(error, kind: kind))
        }

        let attributes = try? fileManager.attributesOfItem(atPath: destination.path)
        let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        let modified = (attributes?[.modificationDate] as? Date) ?? Date()

        var destinationIsDirectory: ObjCBool = false
        _ = fileManager.fileExists(atPath: destination.path, isDirectory: &destinationIsDirectory)

        logInfo("\(kind.verb)d \(source.path) -> \(destination.path)")

        return .success([
            "sourcePath": source.path,
            "destinationPath": destination.path,
            "renamed": renamed,
            "sameVolume": sameVolume,
            "size": size,
            "modifiedEpochMs": Int(modified.timeIntervalSince1970 * 1000),
            "isDirectory": destinationIsDirectory.boolValue,
        ])
    }

    /// Finds the first unused "name 2.ext", "name 3.ext", … next to `url`,
    /// matching Finder's keep-both convention. Returns nil if the suffixes are
    /// exhausted.
    private func uniqueDestination(for url: URL) -> URL? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return url }

        let directory = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent

        for suffix in 2...1000 {
            let name = ext.isEmpty ? "\(base) \(suffix)" : "\(base) \(suffix).\(ext)"
            let candidate = directory.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private func volumeIdentifier(of url: URL) -> NSObject? {
        guard let values = try? url.resourceValues(forKeys: [.volumeIdentifierKey]) else {
            return nil
        }
        return values.volumeIdentifier as? NSObject
    }

    private func isSameVolume(_ lhs: URL, _ rhs: URL) -> Bool {
        guard let lhsVolume = volumeIdentifier(of: lhs),
              let rhsVolume = volumeIdentifier(of: rhs) else {
            return false
        }
        return lhsVolume.isEqual(rhsVolume)
    }

    private func transferError(_ error: Error, kind: TransferKind) -> FlutterError {
        let nsError = error as NSError
        let code: String
        switch nsError.code {
        case NSFileWriteNoPermissionError, NSFileReadNoPermissionError:
            code = "BOOKMARK_ACCESS"
        case NSFileWriteOutOfSpaceError:
            code = "INSUFFICIENT_SPACE"
        case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
            code = "SOURCE_NOT_FOUND"
        case NSFileWriteFileExistsError:
            code = "DESTINATION_EXISTS"
        default:
            code = kind.failureCode
        }

        return FlutterError(code: code,
                           message: "\(kind.verb) failed: \(error.localizedDescription)",
                           details: nil)
    }

    // MARK: - Trash

    /// Moves a file or directory to the Trash (recoverable), running the
    /// operation inside security-scoped access to the enclosing bookmarked
    /// directory when a bookmark is provided.
    private func handleMoveToTrash(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
            logError("Invalid arguments for moveToTrash")
            result(FlutterError(code: "INVALID_ARGUMENTS",
                               message: "Path is required",
                               details: nil))
            return
        }

        // Start security-scoped access on the enclosing directory bookmark so a
        // sandboxed build is permitted to modify the user-selected location.
        let scopes = ScopedAccess()
        defer { scopes.endAll() }
        scopes.begin(args["bookmarkData"] as? String, label: "enclosing directory") { self.logWarning($0) }

        let fileURL = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            result(FlutterError(code: "NOT_FOUND",
                               message: "File does not exist: \(path)",
                               details: nil))
            return
        }

        do {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: fileURL, resultingItemURL: &resultingURL)
            logInfo("Moved item to Trash: \(path)")
            result(resultingURL?.path ?? path)
        } catch {
            logError("Failed to move item to Trash \(path): \(error)")
            let message = error.localizedDescription.lowercased()
            let code = (message.contains("permission") || message.contains("not permitted"))
                ? "BOOKMARK_ACCESS"
                : "TRASH_FAILED"
            result(FlutterError(code: code,
                               message: "Failed to move item to Trash: \(error.localizedDescription)",
                               details: nil))
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