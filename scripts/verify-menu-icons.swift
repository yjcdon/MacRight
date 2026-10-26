import AppKit
import Foundation

/// Verifies the actual menu-image loader against the built extension's bundled resources.
@main
struct MenuIconVerification {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 2,
              let bundle = Bundle(path: CommandLine.arguments[1]) else {
            throw CocoaError(.fileNoSuchFile)
        }
        for kind in FileKind.allCases {
            guard let image = kind.menuIcon(in: bundle), image.isValid,
                  image.size == NSSize(width: 16, height: 16),
                  image.isTemplate == (kind == .text || kind == .markdown) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            print("PASS: \(kind.rawValue) icon decodes at 16pt; template=\(image.isTemplate)")
        }
    }
}
