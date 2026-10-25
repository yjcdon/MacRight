import Foundation
import Darwin
import FinderSync

/// Runs reproducible checks against the production core without a test framework or test classes.
@main
struct CoreVerification {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count >= 2 else { throw Failure("Pass the MacRight repository path.") }
        let root = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let service = FileCreationService(templateDirectory: root.appendingPathComponent("Resources/Templates/Office"))

        if arguments.count == 4, arguments[2] == "--create-one" {
            let output = try service.create(kind: .word, in: URL(fileURLWithPath: arguments[3]), baseName: "Concurrent")
            print(output.lastPathComponent)
            return
        }

        if arguments.count == 4, arguments[2] == "--write-limit" {
            try verifyPartialWriteFailure(service: service, directory: URL(fileURLWithPath: arguments[3]))
            print("PASS: real partial-write failures remove only owned output and release descriptors")
            return
        }

        let fixture = root.appendingPathComponent("build/core-verification/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
        let nested = fixture.appendingPathComponent("中文 space ' \" $ & folder", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let sourceTemplates = try Dictionary(uniqueKeysWithValues: FileKind.allCases.compactMap { kind -> (FileKind, Data)? in
            guard let template = kind.templateName else { return nil }
            return (kind, try Data(contentsOf: service.templateDirectory.appendingPathComponent(template)))
        })

        try expect(FileKind.allCases.map(\.fileExtension) == ["txt", "md", "docx", "xlsx", "pptx"], "Exactly five supported formats")
        for kind in FileKind.allCases {
            let created = try service.create(kind: kind, in: nested, baseName: "未命名")
            try expect(created.deletingLastPathComponent() == nested, "Special-character destination")
            let expected = sourceTemplates[kind] ?? Data()
            try expect(try Data(contentsOf: created) == expected, "Exact template content for \(kind)")
            let second = try service.create(kind: kind, in: nested, baseName: "未命名")
            try expect(second.lastPathComponent == "未命名 (1).\(kind.fileExtension)", "Collision naming for \(kind)")
            try expect(try Data(contentsOf: created) == expected, "Original file is not overwritten")
        }
        print("PASS: five formats, exact Office copies, empty text files, special paths, collision naming")

        let parallel = try await withThrowingTaskGroup(of: URL.self) { group in
            for _ in 0..<40 {
                group.addTask { try service.create(kind: .word, in: nested, baseName: "Concurrent") }
            }
            var outputs = [URL]()
            for try await url in group { outputs.append(url) }
            return outputs
        }
        try expect(Set(parallel).count == 40, "Concurrent calls allocate distinct files")
        for url in parallel { try expect(try Data(contentsOf: url) == sourceTemplates[.word], "Concurrent document bytes") }
        print("PASS: 40 concurrent creations have distinct names and exact template bytes")

        let processes = try (0..<8).map { _ -> Process in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
            process.arguments = [root.path, "--create-one", nested.path]
            process.standardOutput = FileHandle.nullDevice
            try process.run()
            return process
        }
        for process in processes {
            process.waitUntilExit()
            try expect(process.terminationStatus == 0, "Concurrent process exited successfully")
        }
        let concurrentNames = try FileManager.default.contentsOfDirectory(at: nested, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("Concurrent") }
        try expect(concurrentNames.count == 48, "Eight separate processes do not overwrite the original forty files")
        print("PASS: 8 additional processes create files without overwriting")

        let text = nested.appendingPathComponent("existing.txt")
        try Data("existing content".utf8).write(to: text)
        let package = nested.appendingPathComponent("Document.pages", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: false)
        let sibling = fixture.appendingPathComponent("sibling", isDirectory: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: false)
        let alias = fixture.appendingPathComponent("folder-link", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: nested)
        let resolve = FinderContextResolver.resolve
        let folderContext = resolve(.contextualMenuForItems, nested, [nested])
        try expect(folderContext?.directoryURL == nested.resolvingSymlinksInPath(), "Single folder targets folder contents")
        try expect(resolve(.contextualMenuForItems, text, [text])?.directoryURL == nested.resolvingSymlinksInPath(), "Single file targets its parent")
        try expect(resolve(.contextualMenuForItems, package, [package])?.directoryURL == nested.resolvingSymlinksInPath(), "Document package targets its parent")
        try expect(resolve(.contextualMenuForItems, text, [text, package])?.directoryURL == nested.resolvingSymlinksInPath(), "Multi-selection uses common parent")
        try expect(resolve(.contextualMenuForItems, text, [text, sibling])?.directoryURL == nil, "Mixed parent selection has no destination")
        let aliasContext = resolve(.contextualMenuForItems, alias, [alias])
        try expect(aliasContext?.copyURLs == [alias] && aliasContext?.directoryURL == nested.resolvingSymlinksInPath(), "Symlink copies lexical path and targets real directory")
        try expect(resolve(.contextualMenuForContainer, nested, [text])?.copyURLs == [nested], "Background ignores stale selected items")
        try expect(resolve(.contextualMenuForSidebar, nested, [text])?.directoryURL == nested.resolvingSymlinksInPath(), "Sidebar uses targeted folder")
        try expect(resolve(.toolbarItemMenu, nested, [text]) == nil, "Toolbar callback has no actions")
        try expect(resolve(.contextualMenuForItems, nested, []) == nil, "Empty item selection has no actions")
        try expect(resolve(.contextualMenuForItems, nested, [URL(string: "https://example.com")!]) == nil, "Non-file selection is rejected")
        print("PASS: Finder background, folder, file, package, multi-selection, sidebar, symlink and toolbar contexts")

        try expectThrows("invalid name") { _ = try service.create(kind: .text, in: nested, baseName: "../escape") }
        try expectThrows("missing destination") { _ = try service.create(kind: .text, in: fixture.appendingPathComponent("missing"), baseName: "Untitled") }
        try expectThrows("file used as destination") { _ = try service.create(kind: .text, in: text, baseName: "Untitled") }
        let missingTemplates = FileCreationService(templateDirectory: fixture)
        try expectThrows("missing template") { _ = try missingTemplates.create(kind: .word, in: nested, baseName: "Missing") }
        try expect(!FileManager.default.fileExists(atPath: nested.appendingPathComponent("Missing.docx").path), "Template failure leaves no empty document")
        try Data().write(to: fixture.appendingPathComponent("Blank.docx"))
        try expectThrows("empty template") { _ = try missingTemplates.create(kind: .word, in: nested, baseName: "EmptyTemplate") }
        try expect(!FileManager.default.fileExists(atPath: nested.appendingPathComponent("EmptyTemplate.docx").path), "Empty template leaves no empty document")
        let writeFailureFolder = fixture.appendingPathComponent("partial-write", isDirectory: true)
        try FileManager.default.createDirectory(at: writeFailureFolder, withIntermediateDirectories: false)
        let writeFailureProcess = Process()
        writeFailureProcess.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        writeFailureProcess.arguments = [root.path, "--write-limit", writeFailureFolder.path]
        try writeFailureProcess.run()
        writeFailureProcess.waitUntilExit()
        try expect(writeFailureProcess.terminationStatus == 0, "Partial-write failure cleanup")

        let blocked = fixture.appendingPathComponent("read-only", isDirectory: true)
        try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: false)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: blocked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: blocked.path) }
        try expectThrows("read-only directory") { _ = try service.create(kind: .text, in: blocked, baseName: "Untitled") }
        for (kind, original) in sourceTemplates {
            try expect(try Data(contentsOf: service.templateDirectory.appendingPathComponent(kind.templateName!)) == original, "Template was not modified")
        }
        print("PASS: invalid input, missing template, deleted destination and write-denied errors; templates unchanged")
        let descriptorsBefore = try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count
        for _ in 0..<100 {
            _ = try service.create(kind: .text, in: nested, baseName: "DescriptorCheck")
        }
        let descriptorsAfter = try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count
        try expect(descriptorsAfter == descriptorsBefore, "Repeated creation releases every file descriptor")
        print("PASS: 100 additional creations leave the open file descriptor count unchanged")
        print("Verification files: \(fixture.path)")
    }

    /// Exercises the production error path with the kernel's real file-size limit in a child process.
    private static func verifyPartialWriteFailure(service: FileCreationService, directory: URL) throws {
        var originalLimit = rlimit()
        try expect(getrlimit(RLIMIT_FSIZE, &originalLimit) == 0, "Read file-size limit")
        var limited = originalLimit
        limited.rlim_cur = 16
        let previousSignal = signal(SIGXFSZ, SIG_IGN)
        defer { signal(SIGXFSZ, previousSignal) }
        try expect(setrlimit(RLIMIT_FSIZE, &limited) == 0, "Set partial-write limit")
        defer { precondition(setrlimit(RLIMIT_FSIZE, &originalLimit) == 0) }
        let descriptorsBefore = try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count
        for attempt in 0..<5 {
            let name = "WriteFailure\(attempt)"
            try expectThrows("kernel partial-write failure") {
                _ = try service.create(kind: .word, in: directory, baseName: name)
            }
            try expect(
                !FileManager.default.fileExists(atPath: directory.appendingPathComponent(name + ".docx").path),
                "Owned partial file was moved to Trash"
            )
        }
        let descriptorsAfter = try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count
        try expect(descriptorsAfter == descriptorsBefore, "Partial-write failures release file descriptors")
    }

    private struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }

    private static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !condition() { throw Failure(message) }
    }

    private static func expectThrows(_ message: String, operation: () throws -> Void) throws {
        do { try operation() } catch { return }
        throw Failure("Expected failure: \(message)")
    }
}
