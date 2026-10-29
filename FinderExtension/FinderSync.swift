// Author: liangyujia-ai

import AppKit
import FinderSync
import Foundation

/// Bridges legacy synchronous Objective-C callbacks to one main-actor menu controller.
@objc(MacRightFinderSync)
final class MacRightFinderSync: FIFinderSync {
    private let controller: FinderMenuController

    override init() {
        controller = onMainActor { FinderMenuController(volumeMonitor: VolumeMonitor()) }
        super.init()
        let controller = controller
        onMainActor { controller.start() }
    }

    /// Returns synchronously, while all access to the menu and controller happens on the main thread.
    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let controller = controller
        return onMainActor {
            SynchronousMenuResult(menu: controller.menu(for: menuKind))
        }.menu
    }

    /// Finder routes menu selectors to the principal extension, regardless of an item's target.
    @objc func performAction(_ sender: NSMenuItem) {
        let tag = sender.tag
        let controller = controller
        onMainActor { controller.performAction(tag: tag) }
    }
}

/// Executes Finder's synchronous callbacks on the main actor before returning their result.
private func onMainActor<T: Sendable>(_ operation: @MainActor () -> T) -> T {
    if Thread.isMainThread { return MainActor.assumeIsolated(operation) }
    return DispatchQueue.main.sync { operation() }
}

/// Only used to return a completed AppKit menu through the synchronous Objective-C callback.
/// The producer finishes on the main thread before the wrapper is read; no menu work runs in parallel.
private struct SynchronousMenuResult: @unchecked Sendable {
    let menu: NSMenu?
}

/// Owns all mutable action state and AppKit interactions on the main actor.
@MainActor
private final class FinderMenuController {
    private let volumeMonitor: VolumeMonitor
    private let accessStore = DirectoryAccessStore()
    private var isCreatingFile = false
    private var commands: [Int: FinderAction] = [:]
    private var nextCommandTag = 1

    init(volumeMonitor: VolumeMonitor) {
        self.volumeMonitor = volumeMonitor
    }

    /// Starts Finder subscriptions after the principal extension's superclass has initialized.
    func start() {
        volumeMonitor.start()
    }

    func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let controller = FIFinderSyncController.default()
        guard let context = FinderContextResolver.resolve(
            kind: menuKind,
            targetedURL: controller.targetedURL(),
            selectedURLs: controller.selectedItemURLs() ?? []
        ) else { return nil }

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(item(
            NSLocalizedString("Copy Path", comment: "Finder action"),
            symbol: "doc.on.clipboard", action: .copy(context.copyURLs)
        ))
        if let directory = context.directoryURL {
            menu.addItem(item(
                NSLocalizedString("Open in Terminal", comment: "Finder action"),
                symbol: "terminal", action: .terminal(directory)
            ))
            let newFile = NSMenuItem(
                title: NSLocalizedString("New File", comment: "New file submenu"), action: nil, keyEquivalent: ""
            )
            newFile.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
            newFile.image?.isTemplate = true
            let submenu = NSMenu()
            submenu.autoenablesItems = false
            let bundle = Bundle(for: MacRightFinderSync.self)
            for kind in FileKind.allCases {
                let entry = item(kind.title, symbol: nil, action: .create(kind, directory))
                entry.image = kind.menuIcon(in: bundle)
                entry.isEnabled = !isCreatingFile || accessStore.isAwaitingAuthorization
                submenu.addItem(entry)
            }
            newFile.submenu = submenu
            menu.addItem(newFile)
        }
        return menu
    }

    private func item(
        _ title: String, symbol: String?, action: FinderAction
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: #selector(MacRightFinderSync.performAction(_:)), keyEquivalent: ""
        )
        // Finder transports the numeric tag; custom representedObject values aren't its action contract.
        item.tag = nextCommandTag
        commands[nextCommandTag] = action
        nextCommandTag += 1
        // Retain recent menu snapshots, including menus requested by other Finder windows.
        commands.removeValue(forKey: nextCommandTag - 257)
        if let symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            item.image?.isTemplate = true
        }
        return item
    }

    /// Executes the clicked menu's captured action without consulting a later Finder selection.
    func performAction(tag: Int) {
        guard let command = commands[tag] else {
            SystemActions.present(error: NSError(
                domain: "com.yjcdon.MacRight.Menu", code: 1,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("This menu has expired. Please reopen it.", comment: "Expired Finder menu")]
            ))
            return
        }
        switch command {
        case .copy(let urls):
            do { try SystemActions.copyPaths(urls) }
            catch { SystemActions.present(error: error) }
        case .terminal(let directory):
            Task {
                do { try await SystemActions.openTerminal(at: directory) }
                catch { SystemActions.present(error: error) }
            }
        case .create(let kind, let directory):
            if isCreatingFile {
                accessStore.presentPendingAuthorization()
                return
            }
            isCreatingFile = true
            Task {
                defer { isCreatingFile = false }
                do {
                    guard let resources = Bundle(for: MacRightFinderSync.self).resourceURL else {
                        throw CocoaError(.fileNoSuchFile)
                    }
                    let service = FileCreationService(templateDirectory: resources.appendingPathComponent("Templates"))
                    let baseName = NSLocalizedString("Untitled", comment: "Default new document name")
                    let output = try await accessStore.withAccess(to: directory) {
                        try service.create(kind: kind, in: directory, baseName: baseName)
                    }
                    SystemActions.reveal(output)
                } catch {
                    SystemActions.present(error: error)
                }
            }
        }
    }
}

/// Stores only the inputs required by each action, captured when Finder builds the menu.
private enum FinderAction {
    case copy([URL])
    case terminal(URL)
    case create(FileKind, URL)
}
