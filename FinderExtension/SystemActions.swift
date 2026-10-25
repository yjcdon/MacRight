// Author: liangyujia-ai

import AppKit
import Foundation
import OSLog

enum SystemActionError: LocalizedError {
    case noPaths
    case clipboardUnavailable
    case terminalUnavailable
    case invalidDirectory

    var errorDescription: String? {
        switch self {
        case .noPaths:
            return NSLocalizedString("There are no file paths to copy.", comment: "Missing clipboard input")
        case .clipboardUnavailable:
            return NSLocalizedString("The clipboard could not be updated. Try copying the paths again.", comment: "Clipboard failure")
        case .terminalUnavailable:
            return NSLocalizedString("Terminal could not be found on this Mac.", comment: "Missing Terminal")
        case .invalidDirectory:
            return NSLocalizedString("The target folder no longer exists.", comment: "Missing action directory")
        }
    }
}

/// Performs Finder-visible actions with native APIs; file paths never become executable source text.
@MainActor
enum SystemActions {
    private static let logger = Logger(subsystem: "com.yjcdon.MacRight", category: "Actions")

    /// Selects the already-created file; this action never repeats file creation.
    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Displays actionable operation failures, while treating a cancelled folder grant as a quiet result.
    static func present(error: Error) {
        guard !DirectoryAccessStore.isCancellation(error) else { return }
        logger.error("An operation failed: \(error.localizedDescription, privacy: .private)")
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("MacRight Could Not Complete the Operation", comment: "Action error title")
        let recovery = (error as? LocalizedError)?.recoverySuggestion ?? (error as NSError).localizedRecoverySuggestion
        alert.informativeText = [error.localizedDescription, recovery].compactMap { $0 }.joined(separator: "\n\n")
        alert.addButton(withTitle: NSLocalizedString("OK", comment: "Dismiss error"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
