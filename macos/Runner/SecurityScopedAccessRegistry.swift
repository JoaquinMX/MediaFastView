import Foundation

/// A resource whose security-scoped access can be balanced explicitly.
protocol SecurityScopedResource {
    var path: String { get }

    func startAccessingSecurityScopedResource() -> Bool
    func stopAccessingSecurityScopedResource()
}

extension URL: SecurityScopedResource {}

/// Resolves security-scoped bookmarks and keeps each resolved URL alive until
/// its final matching release.
final class SecurityScopedAccessRegistry {
    typealias Resolver = (Data) throws -> any SecurityScopedResource

    private struct Entry {
        let resource: any SecurityScopedResource
        var referenceCount: Int
    }

    init(
        resolver: @escaping Resolver = SecurityScopedAccessRegistry.resolve,
        logWarning: @escaping (String) -> Void = { message in
            print("[SecurityScopedAccessRegistry] WARNING: \(message)")
        }
    ) {
        self.resolver = resolver
        self.logWarning = logWarning
    }

    private let resolver: Resolver
    private let logWarning: (String) -> Void
    private let lock = NSLock()
    private var entries: [String: Entry] = [:]

    /// Starts or retains access for [bookmarkBase64] and returns its path.
    func acquire(_ bookmarkBase64: String) throws -> String {
        lock.lock()
        defer { lock.unlock() }

        if var entry = entries[bookmarkBase64] {
            entry.referenceCount += 1
            entries[bookmarkBase64] = entry
            return entry.resource.path
        }

        guard let bookmarkData = Data(base64Encoded: bookmarkBase64) else {
            throw NSError(
                domain: "SecurityScopedAccessRegistry",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Bookmark data is not valid base64"]
            )
        }

        let resource = try resolver(bookmarkData)
        guard resource.startAccessingSecurityScopedResource() else {
            throw NSError(
                domain: "SecurityScopedAccessRegistry",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to start security-scoped access"]
            )
        }

        entries[bookmarkBase64] = Entry(resource: resource, referenceCount: 1)
        return resource.path
    }

    /// Releases one acquisition, stopping the original URL at zero references.
    func release(_ bookmarkBase64: String) {
        lock.lock()

        guard var entry = entries[bookmarkBase64] else {
            lock.unlock()
            logWarning("Ignoring an unmatched security-scoped release")
            return
        }

        entry.referenceCount -= 1
        if entry.referenceCount > 0 {
            entries[bookmarkBase64] = entry
            lock.unlock()
            return
        }

        entries.removeValue(forKey: bookmarkBase64)
        lock.unlock()
        entry.resource.stopAccessingSecurityScopedResource()
    }

    /// Stops every currently held resource. Intended for application teardown.
    func releaseAll() {
        lock.lock()
        let resources = entries.values.map(\.resource)
        entries.removeAll()
        lock.unlock()

        for resource in resources {
            resource.stopAccessingSecurityScopedResource()
        }
    }

    private static func resolve(_ bookmarkData: Data) throws -> any SecurityScopedResource {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale {
            print("[SecurityScopedAccessRegistry] WARNING: Resolved bookmark is stale")
        }
        return url
    }
}
