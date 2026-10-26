// Author: liangyujia-ai

import AppKit
import FinderSync
import Foundation

/// Bridges legacy synchronous Objective-C callbacks to one main-actor menu controller.
@objc(MacRightFinderSync)
final class MacRightFinderSync: FIFinderSync {
    private let controller: FinderMenuController

    override init() {
        let makeController: @MainActor () -> FinderMenuController = {
            FinderMenuController(volumeMonitor: VolumeMonitor())
        }
        if Thread.isMainThread {
            controller = MainActor.assumeIsolated(makeController)
        } else {
            controller = DispatchQueue.main.sync { makeController() }
        }
        super.init()
        let controller = controller
        if Thread.isMainThread {
            MainActor.assumeIsolated { controller.start() }
        } else {
            DispatchQueue.main.sync { controller.start() }
        }
    }

    /// Returns synchronously, while all access to the menu and controller happens on the main thread.
    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let controller = controller
        let makeMenu: @MainActor () -> SynchronousMenuResult = {
            SynchronousMenuResult(menu: controller.menu(for: menuKind))
        }
        if Thread.isMainThread {
            return MainActor.assumeIsolated(makeMenu).menu
        }
        return DispatchQueue.main.sync { makeMenu() }.menu
    }

    /// Finder routes menu selectors to the principal extension, regardless of an item's target.
    @objc func performAction(_ sender: NSMenuItem) {
        let tag = sender.tag
        let controller = controller
        if Thread.isMainThread {
            MainActor.assumeIsolated { controller.performAction(tag: tag) }
        } else {
            DispatchQueue.main.sync { controller.performAction(tag: tag) }
        }
    }
}

/// Only used to return a completed AppKit menu through the synchronous Objective-C callback.
/// The producer finishes on the main thread before the wrapper is read; no menu work runs in parallel.
private struct SynchronousMenuResult: @unchecked Sendable {
    let menu: NSMenu?
}

/// Owns all mutable action state and AppKit interactions on the main actor.
@MainActor
private final class FinderMenuController: NSObject {
    private let volumeMonitor: VolumeMonitor
    private let accessStore = DirectoryAccessStore()
    private var isPerformingDirectoryAction = false
    private var commands: [Int: MenuAction] = [:]
    private var nextCommandTag = 1

    init(volumeMonitor: VolumeMonitor) {
        self.volumeMonitor = volumeMonitor
        super.init()
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
        menu.addItem(item("Copy Path", symbol: "doc.on.clipboard", action: .copy, context: context))
        if context.directoryURL != nil {
            let terminal = item("Open in Terminal", symbol: "terminal", action: .terminal, context: context)
            terminal.isEnabled = !isPerformingDirectoryAction
            menu.addItem(terminal)
            let newFile = NSMenuItem(
                title: NSLocalizedString("New File", comment: "New file submenu"), action: nil, keyEquivalent: ""
            )
            newFile.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
            newFile.image?.isTemplate = true
            let submenu = NSMenu()
            submenu.autoenablesItems = false
            let bundle = Bundle(for: MacRightFinderSync.self)
            for kind in FileKind.allCases {
                let entry = item(kind.title, symbol: nil, action: .create(kind), context: context, localized: true)
                entry.image = kind.menuIcon(in: bundle)
                entry.isEnabled = !isPerformingDirectoryAction
                submenu.addItem(entry)
            }
            newFile.submenu = submenu
            menu.addItem(newFile)
        }
        return menu
    }

    private func item(
        _ title: String, symbol: String?, action: FinderAction, context: FinderContext, localized: Bool = false
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: localized ? title : NSLocalizedString(title, comment: "Finder action"),
            action: #selector(MacRightFinderSync.performAction(_:)), keyEquivalent: ""
        )
        // Finder transports the numeric tag; custom representedObject values aren't its action contract.
        item.tag = nextCommandTag
        commands[nextCommandTag] = MenuAction(action: action, context: context)
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
        switch command.action {
        case .copy:
            do { try SystemActions.copyPaths(command.context.copyURLs) }
            catch { SystemActions.present(error: error) }
        case .terminal:
            guard !isPerformingDirectoryAction, let directory = command.context.directoryURL else { return }
            isPerformingDirectoryAction = true
            Task {
                defer { isPerformingDirectoryAction = false }
                do {
                    try await accessStore.withAccess(to: directory, requiresWrite: false) {
                        try await SystemActions.openTerminal(at: directory)
                    }
                }
                catch { SystemActions.present(error: error) }
            }
        case .create(let kind):
            guard !isPerformingDirectoryAction, let directory = command.context.directoryURL else { return }
            isPerformingDirectoryAction = true
            Task {
                defer { isPerformingDirectoryAction = false }
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

private enum FinderAction {
    case copy
    case terminal
    case create(FileKind)
}

/// Retains the original menu context without retaining AppKit menu objects.
private struct MenuAction {
    let action: FinderAction
    let context: FinderContext

    init(action: FinderAction, context: FinderContext) {
        self.action = action
        self.context = context
    }
}
