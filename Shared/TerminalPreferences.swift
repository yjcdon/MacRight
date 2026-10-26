// Author: liangyujia-ai

import CoreFoundation
import Foundation

enum TerminalPreferencesError: LocalizedError {
    case invalidValue
    case synchronizationFailed

    var errorDescription: String? {
        switch self {
        case .invalidValue:
            return NSLocalizedString(
                "The preferred terminal setting is invalid. Choose a terminal in MacRight.",
                comment: "Invalid terminal preference"
            )
        case .synchronizationFailed:
            return NSLocalizedString(
                "The terminal preference could not be synchronized. Try again.",
                comment: "Terminal preference persistence failure"
            )
        }
    }
}

/// Shares one terminal selection through the main application's preference domain.
enum TerminalPreferences {
    static let domain = "com.yjcdon.MacRight"
    private static let key = "PreferredTerminal"

    /// Refreshes cross-process preferences for every action; an unset preference selects macOS Terminal.
    static func load() throws -> TerminalApplication {
        guard CFPreferencesAppSynchronize(domain as CFString) else {
            throw TerminalPreferencesError.synchronizationFailed
        }
        guard let stored = CFPreferencesCopyAppValue(key as CFString, domain as CFString) else {
            return .systemTerminal
        }
        guard let data = stored as? Data else {
            throw TerminalPreferencesError.invalidValue
        }
        do {
            return try JSONDecoder().decode(TerminalApplication.self, from: data)
        } catch {
            throw TerminalPreferencesError.invalidValue
        }
    }

    /// Persists the selected application before reporting success to the settings interface.
    static func save(_ application: TerminalApplication) throws {
        let data = try JSONEncoder().encode(application)
        CFPreferencesSetAppValue(key as CFString, data as CFData, domain as CFString)
        guard CFPreferencesAppSynchronize(domain as CFString) else {
            throw TerminalPreferencesError.synchronizationFailed
        }
    }
}
