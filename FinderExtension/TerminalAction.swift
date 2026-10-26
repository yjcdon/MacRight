// Author: liangyujia-ai

import AppKit
import Foundation

enum TerminalLaunchError: LocalizedError {
    case applicationUnavailable(TerminalApplication)

    var errorDescription: String? {
        switch self {
        case .applicationUnavailable(let application):
            return String(
                format: NSLocalizedString("The selected application %@ is unavailable at its saved location.", comment: "Selected application is missing"),
                application.title
            )
        }
    }

    var recoverySuggestion: String? {
        NSLocalizedString(
            "Choose the application again in MacRight.",
            comment: "Missing application recovery"
        )
    }
}

extension SystemActions {
    /// Opens a folder in the configured terminal; unavailable selections are reported without a fallback.
    static func openTerminal(at directory: URL) async throws {
        guard directory.isFileURL else { throw SystemActionError.invalidDirectory }
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { throw SystemActionError.invalidDirectory }
        let selected = try TerminalPreferences.load()
        let terminal: URL
        if let path = selected.applicationPath {
            let exactURL = URL(fileURLWithPath: path, isDirectory: true)
            guard FileManager.default.fileExists(atPath: path),
                  (try? exactURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                throw TerminalLaunchError.applicationUnavailable(selected)
            }
            terminal = exactURL
        } else {
            guard let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: selected.bundleIdentifier) else {
                throw TerminalLaunchError.applicationUnavailable(selected)
            }
            terminal = installed
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.allowsRunningApplicationSubstitution = false
        try await NSWorkspace.shared.open([directory], withApplicationAt: terminal, configuration: configuration)
    }
}
