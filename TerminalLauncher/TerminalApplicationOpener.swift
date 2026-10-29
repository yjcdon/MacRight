// Author: liangyujia-ai

import AppKit
import Foundation

@MainActor
enum TerminalApplicationOpener {
    /// Opens a validated local directory using the user's saved terminal application and native URL handling.
    static func open(at directory: URL) async throws {
        guard directory.isFileURL,
              try directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        let terminal = try TerminalPreferences.load().installedURL()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.allowsRunningApplicationSubstitution = false
        try await NSWorkspace.shared.open([directory], withApplicationAt: terminal, configuration: configuration)
    }
}
