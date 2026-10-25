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
            return String(format: NSLocalizedString("A file may remain at %@. Check this location before trying again.", comment: "Partial file location"), url.path)
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
            // close() may release the descriptor even when it reports a writeback error.
            // Capture ownership while the descriptor is valid, before writing or closing it.
            var createdFile = stat()
            let identityStatus = fstat(descriptor, &createdFile)
            let identityError = errno
            do {
                guard identityStatus == 0 else { throw posixError(identityError, url: target) }
                try handle.write(contentsOf: content)
                try handle.close()
                return target
            } catch {
                let writeError = error
                var current = stat()
                let pathStatus = lstat(target.path, &current)
                let pathError = errno
                let ownsPath = identityStatus == 0 && pathStatus == 0
                    && createdFile.st_dev == current.st_dev && createdFile.st_ino == current.st_ino
                try? handle.close()
                if ownsPath {
                    do {
                        try FileManager.default.trashItem(at: target, resultingItemURL: nil)
                    } catch {
                        throw FileCreationError.cleanupFailed(target, writeError: writeError, cleanupError: error)
                    }
                } else if pathStatus == 0 || pathError != ENOENT {
                    // A renamed or replaced path cannot safely be removed as this operation's file.
                    throw FileCreationError.cleanupFailed(
                        target, writeError: writeError,
                        cleanupError: posixError(pathStatus == 0 ? ESTALE : pathError, url: target)
                    )
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
