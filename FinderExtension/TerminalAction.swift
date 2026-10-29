// Author: liangyujia-ai

import AppKit
import Foundation

extension SystemActions {
    /// Hands Finder's directory to the bundled launcher without requesting directory access in the extension.
    static func openTerminal(at directory: URL) async throws {
        let helper = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Helpers/MacRightTerminalLauncher.app", isDirectory: true)
        try await launchTerminalRequest(TerminalOpenRequest(directory: directory), using: helper)
    }

    /// Uses the exact bundled launcher; the non-file request URL carries the path without granting file access.
    static func launchTerminalRequest(_ request: TerminalOpenRequest, using helper: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.createsNewApplicationInstance = true
        configuration.allowsRunningApplicationSubstitution = false
        try await NSWorkspace.shared.open([request.url], withApplicationAt: helper, configuration: configuration)
    }
}
