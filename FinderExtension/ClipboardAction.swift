// Author: liangyujia-ai

import AppKit
import Foundation

extension SystemActions {
    /// Copies complete paths in Finder selection order, one item per line.
    static func copyPaths(_ urls: [URL]) throws {
        guard !urls.isEmpty, urls.allSatisfy(\.isFileURL) else { throw SystemActionError.noPaths }
        let text = urls.map(\.path).joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { throw SystemActionError.clipboardUnavailable }
    }

}
