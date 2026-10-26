// Author: liangyujia-ai

import AppKit
import Foundation

extension FileKind {
    /// Reuses the original file-format artwork, adapting only monochrome icons to the menu appearance.
    @MainActor func menuIcon(in bundle: Bundle) -> NSImage? {
        guard let resource = bundle.url(forResource: rawValue, withExtension: "png", subdirectory: "MenuIcons"),
              let image = NSImage(contentsOf: resource) else { return nil }
        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = self == .text || self == .markdown
        return image
    }
}
