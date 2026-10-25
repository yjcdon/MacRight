// Author: liangyujia-ai

import AppKit
import Foundation

extension SystemActions {
    /// Asks Terminal to open the folder as a new terminal session without executing a shell command.
    static func openTerminal(at directory: URL) async throws {
        guard directory.isFileURL else { throw SystemActionError.invalidDirectory }
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { throw SystemActionError.invalidDirectory }
        guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            throw SystemActionError.terminalUnavailable
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        try await NSWorkspace.shared.open([directory], withApplicationAt: terminal, configuration: configuration)
    }

}
