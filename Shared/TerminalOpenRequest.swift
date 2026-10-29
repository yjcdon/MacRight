// Author: liangyujia-ai

import Foundation

/// Carries a directory path through Launch Services as data, preserving Finder's original destination.
struct TerminalOpenRequest: Sendable {
    let directory: URL

    init(directory: URL) throws {
        guard directory.isFileURL, directory.path.hasPrefix("/"), !directory.path.contains("\0") else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        self.directory = directory
    }

    /// Accepts exactly one directory field from the private terminal-launch URL protocol.
    init(url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "macright-terminal", components.host == "open",
              components.path.isEmpty, components.fragment == nil,
              components.user == nil, components.password == nil, components.port == nil,
              let fields = components.queryItems, fields.count == 1,
              fields[0].name == "directory", let path = fields[0].value,
              path.hasPrefix("/"), !path.contains("\0") else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        try self.init(directory: URL(fileURLWithPath: path, isDirectory: true))
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = "macright-terminal"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "directory", value: directory.path)]
        return components.url!
    }
}
