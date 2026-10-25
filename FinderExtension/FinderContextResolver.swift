import Foundation
import FinderSync

/// Captures a Finder selection so asynchronous actions do not read a later selection.
struct FinderContext: Sendable {
    let copyURLs: [URL]
    let directoryURL: URL?
}

enum FinderContextResolver {
    /// Resolves right-click subjects and a single unambiguous destination, excluding packages.
    static func resolve(kind: FIMenuKind, targetedURL: URL?, selectedURLs: [URL]) -> FinderContext? {
        switch kind {
        case .contextualMenuForItems:
            guard !selectedURLs.isEmpty, selectedURLs.allSatisfy(\.isFileURL) else { return nil }
            if selectedURLs.count == 1 {
                return FinderContext(copyURLs: selectedURLs, directoryURL: destination(for: selectedURLs[0]))
            }
            let parents = selectedURLs.map { canonical($0.deletingLastPathComponent()) }
            let commonParent = parents.dropFirst().allSatisfy { $0 == parents[0] } ? parents[0] : nil
            return FinderContext(copyURLs: selectedURLs, directoryURL: commonParent)

        case .contextualMenuForContainer, .contextualMenuForSidebar:
            guard let target = targetedURL, target.isFileURL else { return nil }
            let resolved = canonical(target)
            guard let values = try? resolved.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]),
                  values.isDirectory == true, values.isPackage != true else { return nil }
            return FinderContext(copyURLs: [target], directoryURL: resolved)

        case .toolbarItemMenu:
            return nil
        @unknown default:
            return nil
        }
    }

    /// Treats application and document packages as files, keeping new files outside their contents.
    private static func destination(for url: URL) -> URL? {
        let resolved = canonical(url)
        guard let values = try? resolved.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]) else {
            return nil
        }
        if values.isDirectory == true, values.isPackage != true { return resolved }
        return resolved.deletingLastPathComponent()
    }

    private static func canonical(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}
