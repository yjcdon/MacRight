import AppKit
import Foundation

/// Checks the production clipboard actions and restores all available clipboard representations.
@main
struct SystemVerification {
    @MainActor static func main() throws {
        let pasteboard = NSPasteboard.general
        let originalItems = (pasteboard.pasteboardItems ?? []).map { item in
            item.types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        }
        defer {
            pasteboard.clearContents()
            let restored = originalItems.map { representations in
                let item = NSPasteboardItem()
                for (type, data) in representations { item.setData(data, forType: type) }
                return item
            }
            if !restored.isEmpty { pasteboard.writeObjects(restored) }
        }

        let urls = [
            URL(fileURLWithPath: "/tmp/MacRight 中文 space ' $ &/file.docx"),
            URL(fileURLWithPath: "/tmp/MacRight second.xlsx")
        ]
        try SystemActions.copyPaths([urls[0]])
        try expect(pasteboard.string(forType: .string) == urls[0].path, "Single full path")
        try SystemActions.copyPaths(urls)
        let expected = urls.map(\.path).joined(separator: "\n")
        try expect(pasteboard.string(forType: .string) == expected, "Multiple paths preserve order and exact characters")
        do {
            try SystemActions.copyPaths([])
            throw VerificationFailure(message: "Empty selection was accepted")
        } catch SystemActionError.noPaths {
            try expect(pasteboard.string(forType: .string) == expected, "Invalid selection leaves clipboard unchanged")
        }
        do {
            try SystemActions.copyPaths([URL(string: "https://example.com")!])
            throw VerificationFailure(message: "Non-file URL was accepted")
        } catch SystemActionError.noPaths {}
        try expect(DirectoryAccessStore.isCancellation(DirectoryAccessError.cancelled), "Cancellation is distinguishable")
        try expect(!DirectoryAccessStore.isCancellation(CocoaError(.fileWriteNoPermission)), "Permission failure is not cancellation")
        print("PASS: production clipboard single/multiple paths, exact characters, invalid inputs, cancellation classification")
        print("PASS: original clipboard representations restored on exit")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw VerificationFailure(message: message) }
    }
}

private struct VerificationFailure: Error {
    let message: String
}
