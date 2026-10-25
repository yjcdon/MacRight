// Author: liangyujia-ai

import AppKit
import CryptoKit
import Foundation
import OSLog

/// A cancelled directory grant is an expected user action, not an operation failure.
enum DirectoryAccessError: LocalizedError {
    case cancelled
    case invalidDirectory
    case grantDoesNotCoverTarget
    case accessDenied
    case authorizationInProgress
    case bookmarkPersistenceFailed(Error)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        case .invalidDirectory:
            return NSLocalizedString("Choose a local folder for this operation.", comment: "Invalid directory")
        case .grantDoesNotCoverTarget:
            return NSLocalizedString("Choose the target folder or a parent folder that contains it.", comment: "Wrong directory grant")
        case .accessDenied:
            return NSLocalizedString("macOS did not grant access to this folder. Check its permissions and try again.", comment: "Directory grant failure")
        case .authorizationInProgress:
            return NSLocalizedString("Finish the open folder authorization dialog before trying again.", comment: "Authorization already open")
        case .bookmarkPersistenceFailed:
            return NSLocalizedString("Folder access could not be saved. Check free disk space and try again.", comment: "Bookmark save failure")
        }
    }
}

/// Owns the extension's directory bookmarks; each folder has a separate file for safe multi-process updates.
@MainActor
final class DirectoryAccessStore {
    private let bookmarkDirectory: URL
    private let logger = Logger(subsystem: "com.yjcdon.MacRight", category: "DirectoryAccess")
    private var isPrompting = false

    init(bookmarkDirectory: URL? = nil) {
        self.bookmarkDirectory = bookmarkDirectory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("MacRight/DirectoryBookmarks", isDirectory: true)
    }

    /// Grants access on the main actor, runs file work off the main thread, and always releases its scope.
    func withAccess<T: Sendable>(
        to directory: URL,
        perform: @escaping @Sendable () throws -> T
    ) async throws -> T {
        guard directory.isFileURL else { throw DirectoryAccessError.invalidDirectory }
        let target = directory.standardizedFileURL.resolvingSymlinksInPath()
        let scopedURL = try await authorizedURL(for: target)
        defer { scopedURL.stopAccessingSecurityScopedResource() }
        return try await Task.detached(priority: .userInitiated, operation: perform).value
    }

    /// Distinguishes an explicit user cancellation from file or permission failures.
    static func isCancellation(_ error: Error) -> Bool {
        if case DirectoryAccessError.cancelled = error { return true }
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
    }

    private func authorizedURL(for target: URL) async throws -> URL {
        var candidate = target
        var needsRenewal = false
        // The path has finitely many ancestors, including the volume or filesystem root.
        for _ in 0..<target.pathComponents.count {
            let record = bookmarkFile(for: candidate)
            do {
                let data = try Data(contentsOf: record)
                var stale = false
                let grantedURL = try URL(
                    resolvingBookmarkData: data,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                if covers(grantedURL, target), grantedURL.startAccessingSecurityScopedResource() {
                    do {
                        if stale { try saveBookmark(for: grantedURL) }
                        return grantedURL
                    } catch {
                        grantedURL.stopAccessingSecurityScopedResource()
                        throw error
                    }
                }
                needsRenewal = true
            } catch {
                if case DirectoryAccessError.bookmarkPersistenceFailed = error { throw error }
                let nsError = error as NSError
                if !(nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoSuchFileError) {
                    needsRenewal = true
                    logger.notice("A saved folder authorization needs renewal: \(error.localizedDescription, privacy: .private)")
                }
            }
            let parent = candidate.deletingLastPathComponent()
            if parent == candidate { break }
            candidate = parent
        }
        return try await requestAuthorization(for: target, needsRenewal: needsRenewal)
    }

    private func requestAuthorization(for target: URL, needsRenewal: Bool) async throws -> URL {
        guard !isPrompting else { throw DirectoryAccessError.authorizationInProgress }
        isPrompting = true
        defer { isPrompting = false }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = target
        panel.title = NSLocalizedString("Allow MacRight to Create Files", comment: "Directory authorization title")
        panel.prompt = NSLocalizedString("Allow Access", comment: "Directory authorization button")
        panel.message = needsRenewal
            ? NSLocalizedString("Folder access has expired. Select this folder or a parent folder to renew access.", comment: "Renew directory grant")
            : NSLocalizedString("Select this folder or a parent folder to allow MacRight to create files there.", comment: "Directory grant instructions")
        NSApp.activate(ignoringOtherApps: true)
        let response = await withCheckedContinuation { continuation in
            panel.begin { continuation.resume(returning: $0) }
        }
        guard response == .OK, let selectedURL = panel.url else { throw DirectoryAccessError.cancelled }
        // Open panels implicitly start access for the selected URL.
        defer { selectedURL.stopAccessingSecurityScopedResource() }
        guard covers(selectedURL, target) else { throw DirectoryAccessError.grantDoesNotCoverTarget }
        try saveBookmark(for: selectedURL)
        let data = try Data(contentsOf: bookmarkFile(for: selectedURL))
        var stale = false
        let scopedURL = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        guard scopedURL.startAccessingSecurityScopedResource() else { throw DirectoryAccessError.accessDenied }
        return scopedURL
    }

    private func saveBookmark(for directory: URL) throws {
        let data = try directory.bookmarkData(
            options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil
        )
        do {
            try FileManager.default.createDirectory(at: bookmarkDirectory, withIntermediateDirectories: true)
            try data.write(to: bookmarkFile(for: directory), options: .atomic)
        } catch {
            throw DirectoryAccessError.bookmarkPersistenceFailed(error)
        }
    }

    private func bookmarkFile(for directory: URL) -> URL {
        let path = directory.standardizedFileURL.resolvingSymlinksInPath().path
        let digest = SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
        return bookmarkDirectory.appendingPathComponent(digest + ".bookmark")
    }

    /// Checks actual path components so a sibling named `folder-extra` is never accepted as a child.
    private func covers(_ grantedURL: URL, _ targetURL: URL) -> Bool {
        let granted = grantedURL.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let target = targetURL.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        return target.starts(with: granted)
    }
}
