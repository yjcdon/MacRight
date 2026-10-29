// Author: liangyujia-ai

import AppKit
import Foundation

@main
struct MacRightTerminalLauncher {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let delegate = TerminalLauncherDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
private final class TerminalLauncherDelegate: NSObject, NSApplicationDelegate {
    /// Opens the selected terminal at the supplied directory and exits when the request finishes.
    func application(_ sender: NSApplication, open urls: [URL]) {
        Task {
            do {
                guard urls.count == 1, let url = urls.first else { throw CocoaError(.fileReadInvalidFileName) }
                let request = try TerminalOpenRequest(url: url)
                try await TerminalApplicationOpener.open(at: request.directory)
            } catch {
                let alert = NSAlert(error: error)
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
            NSApp.terminate(nil)
        }
    }
}
