// Author: liangyujia-ai

import Foundation

enum TerminalApplicationError: LocalizedError {
    case invalidApplication

    var errorDescription: String? {
        NSLocalizedString("Choose a valid application (.app).", comment: "Invalid terminal application selection")
    }
}

/// Describes the exact application selected through the system application picker.
struct TerminalApplication: Codable, Equatable, Sendable {
    let bundleIdentifier: String
    let displayName: String
    let applicationPath: String?

    static let systemTerminal = TerminalApplication(
        bundleIdentifier: "com.apple.Terminal", displayName: "System Terminal", applicationPath: nil
    )

    var title: String {
        applicationPath == nil
            ? NSLocalizedString("System Terminal", comment: "Built-in macOS Terminal application")
            : displayName
    }

    /// Accepts an executable application bundle and records its resolved path and localized display name.
    init(applicationURL: URL) throws {
        guard applicationURL.isFileURL else { throw TerminalApplicationError.invalidApplication }
        let resolved = applicationURL.standardizedFileURL.resolvingSymlinksInPath()
        guard resolved.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: resolved),
              bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "APPL",
              let identifier = bundle.bundleIdentifier, !identifier.isEmpty,
              let executable = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path),
              try executable.resolvingSymlinksInPath().resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw TerminalApplicationError.invalidApplication
        }
        bundleIdentifier = identifier
        displayName = ["CFBundleDisplayName", "CFBundleName"]
            .compactMap { bundle.object(forInfoDictionaryKey: $0) as? String }
            .first { !$0.isEmpty }
            ?? resolved.deletingPathExtension().lastPathComponent
        applicationPath = resolved.path
    }

    /// Rejects malformed persisted selections without turning them into a different application.
    init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let identifier = try fields.decode(String.self, forKey: .bundleIdentifier)
        let name = try fields.decode(String.self, forKey: .displayName)
        let path = try fields.decodeIfPresent(String.self, forKey: .applicationPath)
        guard !identifier.isEmpty, !name.isEmpty,
              path.map({ $0.hasPrefix("/") && !$0.contains("\0") && URL(fileURLWithPath: $0).pathExtension.lowercased() == "app" })
                ?? (identifier == Self.systemTerminal.bundleIdentifier) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid terminal application selection"))
        }
        bundleIdentifier = identifier
        displayName = name
        applicationPath = path
    }

    private init(bundleIdentifier: String, displayName: String, applicationPath: String?) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.applicationPath = applicationPath
    }

    private enum CodingKeys: String, CodingKey {
        case bundleIdentifier, displayName, applicationPath
    }
}
