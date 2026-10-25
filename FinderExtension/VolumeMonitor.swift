// Author: liangyujia-ai

import AppKit
import FinderSync
import Foundation
import OSLog

/// Owns one notification subscription and removes it on whichever thread releases the token.
/// NotificationCenter removal is thread-safe; no workspace or actor-isolated API is used during teardown.
private final class WorkspaceObservation {
    private let center: NotificationCenter
    private let token: NSObjectProtocol

    init(center: NotificationCenter, token: NSObjectProtocol) {
        self.center = center
        self.token = token
    }

    deinit { center.removeObserver(token) }
}

/// Updates Finder's menu coverage on volume changes instead of repeatedly scanning mounted volumes.
@MainActor
final class VolumeMonitor {
    private var observations: [WorkspaceObservation] = []
    private var directoryURLs: Set<URL> = []
    private let logger = Logger(subsystem: "com.yjcdon.MacRight", category: "Volumes")

    /// Starts one event subscription per relevant workspace event and publishes the initial volume set.
    func start() {
        guard observations.isEmpty else { return }
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification, NSWorkspace.didRenameVolumeNotification, NSWorkspace.didWakeNotification] {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            observations.append(WorkspaceObservation(center: center, token: token))
        }
    }

    /// Removes observers when the owning extension stops using this monitor.
    func stop() {
        observations.removeAll()
    }

    private func refresh() {
        var updated: Set<URL> = [URL(fileURLWithPath: "/", isDirectory: true)]
        guard let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]
        ) else {
            logger.error("Mounted volumes could not be enumerated; existing menu coverage is preserved.")
            return
        }
        updated.formUnion(volumes)
        guard updated != directoryURLs else { return }
        directoryURLs = updated
        FIFinderSyncController.default().directoryURLs = updated
    }

}
