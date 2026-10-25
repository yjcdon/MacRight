import Foundation
import Darwin

enum FileCreationError: LocalizedError {
    case invalidFileName
    case invalidDirectory
    case emptyTemplate(String)
    case nameLimitReached
    case cleanupFailed(URL, writeError: Error, cleanupError: Error)

    var errorDescription: String? {
        switch self {
        case .invalidFileName:
            return NSLocalizedString("The new file name must be a single nonempty name.", comment: "Invalid file name")
        case .invalidDirectory:
            return NSLocalizedString("The destination is no longer a folder.", comment: "Invalid destination")
        case .emptyTemplate(let name):
            return String(format: NSLocalizedString("The built-in template %@ is empty. Reinstall MacRight.", comment: "Empty template"), name)
        case .nameLimitReached:
            return NSLocalizedString("Too many files already use this name. Rename an existing file and try again.", comment: "Name allocation limit")
        case .cleanupFailed(_, let writeError, _):
            return String(format: NSLocalizedString("The file could not be completed: %@", comment: "Creation and cleanup failed"), writeError.localizedDescription)
        }
    }

    var recoverySuggestion: String? {
        if case .cleanupFailed(let url, _, _) = self {
            return String(format: NSLocalizedString("A partial file remains at %@. Move it to the Trash before trying again.", comment: "Partial file location"), url.path)
        }
        return nil
    }
}

/// Creates documents from trusted bundled resources with filesystem-enforced non-overwrite semantics.
struct FileCreationService: Sendable {
    let templateDirectory: URL
    private let maximumNameAttempts = 10_000

    init(templateDirectory: URL) {
        self.templateDirectory = templateDirectory
    }

    /// Writes an empty text document or an exact template copy, retrying only name collisions.
    func create(kind: FileKind, in directory: URL, baseName: String) throws -> URL {
        guard !baseName.isEmpty, baseName != ".", baseName != "..",
              !baseName.contains("/"), !baseName.contains("\0") else { throw FileCreationError.invalidFileName }
        guard directory.isFileURL,
              try directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            throw FileCreationError.invalidDirectory
        }

        // Read the small bundled template before creating any destination file.
        let content: Data
        if let name = kind.templateName {
            content = try Data(contentsOf: templateDirectory.appendingPathComponent(name))
            guard !content.isEmpty else { throw FileCreationError.emptyTemplate(name) }
        } else {
            content = Data()
        }

        for suffix in 0..<maximumNameAttempts {
            let name = suffix == 0 ? baseName : "\(baseName) (\(suffix))"
            let target = directory.appendingPathComponent(name).appendingPathExtension(kind.fileExtension)
            let descriptor = open(target.path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0o666)
            if descriptor < 0 {
                let code = errno
                if code == EEXIST { continue }
                throw posixError(code, url: target)
            }

            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            do {
                try handle.write(contentsOf: content)
                try handle.close()
                return target
            } catch {
                let writeError = error
                // Keep the file descriptor open while confirming ownership of the partial path.
                var opened = stat()
                var current = stat()
                let ownsPath = fstat(descriptor, &opened) == 0 && lstat(target.path, &current) == 0
                    && opened.st_dev == current.st_dev && opened.st_ino == current.st_ino
                try? handle.close()
                if ownsPath {
                    do {
                        try FileManager.default.trashItem(at: target, resultingItemURL: nil)
                    } catch {
                        throw FileCreationError.cleanupFailed(target, writeError: writeError, cleanupError: error)
                    }
                }
                throw writeError
            }
        }
        throw FileCreationError.nameLimitReached
    }

    private func posixError(_ code: Int32, url: URL) -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(code), userInfo: [NSFilePathErrorKey: url.path])
    }
}
