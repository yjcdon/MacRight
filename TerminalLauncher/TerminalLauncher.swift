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
    /// Creates a file or opens the terminal in one permission identity, then exits.
    func application(_ sender: NSApplication, open urls: [URL]) {
        Task {
            do {
                guard urls.count == 1, let url = urls.first else { throw CocoaError(.fileReadInvalidFileName) }
                let request = try DirectoryActionRequest(url: url)
                switch request.action {
                case .terminal:
                    try await TerminalApplicationOpener.open(at: request.directory)
                case .create(let kind):
                    let templates = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Templates")
                    let service = FileCreationService(templateDirectory: templates)
                    let name = NSLocalizedString("Untitled", comment: "Default new document name")
                    let output = try await Task.detached(priority: .userInitiated) {
                        try service.create(kind: kind, in: request.directory, baseName: name)
                    }.value
                    NSWorkspace.shared.activateFileViewerSelecting([output])
                }
            } catch {
                let alert = NSAlert(error: error)
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
            NSApp.terminate(nil)
        }
    }
}
