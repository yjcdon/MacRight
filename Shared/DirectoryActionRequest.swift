// Author: liangyujia-ai

import Foundation

/// Sends a directory action to the same helper process for file creation and terminal access.
struct DirectoryActionRequest: Sendable {
    enum Action: Sendable { case terminal, create(FileKind) }
    let action: Action
    let directory: URL

    init(action: Action, directory: URL) throws {
        guard directory.isFileURL, directory.path.hasPrefix("/"), !directory.path.contains("\0") else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        self.action = action
        self.directory = directory
    }

    /// Accepts only a known action with exactly its required fields at the process boundary.
    init(url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "macright-terminal", components.path.isEmpty,
              components.fragment == nil, components.user == nil,
              components.password == nil, components.port == nil,
              let fields = components.queryItems,
              fields.first?.name == "directory", let path = fields.first?.value,
              path.hasPrefix("/"), !path.contains("\0") else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        let action: Action
        switch components.host {
        case "open" where fields.count == 1:
            action = .terminal
        case "create" where fields.count == 2:
            guard fields[1].name == "kind", let value = fields[1].value,
                  let kind = FileKind(rawValue: value) else { throw CocoaError(.fileReadInvalidFileName) }
            action = .create(kind)
        default: throw CocoaError(.fileReadInvalidFileName)
        }
        try self.init(action: action, directory: URL(fileURLWithPath: path, isDirectory: true))
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = "macright-terminal"
        components.queryItems = [URLQueryItem(name: "directory", value: directory.path)]
        switch action {
        case .terminal: components.host = "open"
        case .create(let kind):
            components.host = "create"
            components.queryItems?.append(URLQueryItem(name: "kind", value: kind.rawValue))
        }
        return components.url!
    }
}
