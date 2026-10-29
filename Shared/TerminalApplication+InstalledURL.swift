// Author: liangyujia-ai

import AppKit

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
        NSLocalizedString("Choose the application again in MacRight.", comment: "Missing application recovery")
    }
}

extension TerminalApplication {
    /// Resolves and validates the saved application for both settings display and terminal launch.
    @MainActor
    func installedURL() throws -> URL {
        if let path = applicationPath {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            do {
                _ = try TerminalApplication(applicationURL: url)
            } catch {
                throw TerminalLaunchError.applicationUnavailable(self)
            }
            return url
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw TerminalLaunchError.applicationUnavailable(self)
        }
        return url
    }
}
