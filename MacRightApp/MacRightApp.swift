// Author: liangyujia-ai

import AppKit
import FinderSync
import SwiftUI

@main
struct MacRightApp: App {
    @NSApplicationDelegateAdaptor(MacRightApplicationDelegate.self) private var applicationDelegate

    var body: some Scene {
        Window("MacRight", id: "main") {
            ExtensionStatusView()
        }
        .defaultSize(width: 480, height: 430)
        .windowResizability(.contentSize)
    }
}

@MainActor
private final class MacRightApplicationDelegate: NSObject, NSApplicationDelegate {
    /// Releases the guide app when its last window closes; Finder manages the extension independently.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@MainActor
private struct ExtensionStatusView: View {
    @StateObject private var status = ExtensionStatusModel()

    private var extensionEnabled: Bool { status.extensionEnabled }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text("MacRight")
                        .font(.largeTitle.weight(.semibold))
                    Text("Useful actions, right in Finder.")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Label {
                    Text(LocalizedStringKey(extensionEnabled ? "Finder extension is enabled" : "Finder extension is not enabled"))
                        .font(.headline)
                } icon: {
                    Image(systemName: extensionEnabled ? "checkmark.circle.fill" : "info.circle.fill")
                        .foregroundStyle(extensionEnabled ? Color.green : Color.orange)
                }

                Text(LocalizedStringKey(extensionEnabled
                     ? "Right-click in Finder or on your desktop to use MacRight."
                     : "Open extension settings and enable MacRight, then return here to check its status."))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button("Open Extension Settings") {
                        FIFinderSyncController.showExtensionManagementInterface()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Refresh Status", action: status.refresh)
                        .buttonStyle(.bordered)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 9) {
                Label("Create Text, Markdown, Word, Excel, and PowerPoint files", systemImage: "doc.badge.plus")
                Label("Copy full paths, including multiple selected items", systemImage: "doc.on.clipboard")
                Label("Open Terminal in the selected folder", systemImage: "terminal")
            }
            .font(.callout)

            Text("Once enabled, Finder actions remain available when this window is closed.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(width: 480)
        .onAppear(perform: status.refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            status.refresh()
        }
    }
}

@MainActor
private final class ExtensionStatusModel: ObservableObject {
    @Published private(set) var extensionEnabled = FIFinderSyncController.isExtensionEnabled

    /// Refreshes the system-owned extension state when the app becomes active or the user requests it.
    func refresh() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
    }
}
