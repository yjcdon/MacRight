// Author: liangyujia-ai

import AppKit
import Foundation

extension SystemActions {
    /// Forwards file creation and terminal requests through the same installed helper.
    static func perform(_ action: DirectoryActionRequest.Action, at directory: URL) async throws {
        let helper = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Helpers/MacRightTerminalLauncher.app", isDirectory: true)
        let request = try DirectoryActionRequest(action: action, directory: directory)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.createsNewApplicationInstance = true
        configuration.allowsRunningApplicationSubstitution = false
        try await NSWorkspace.shared.open([request.url], withApplicationAt: helper, configuration: configuration)
    }
}
