// Author: liangyujia-ai

import AppKit
import FinderSync
import SwiftUI
import UniformTypeIdentifiers

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

            VStack(alignment: .leading, spacing: 8) {
                Text("Terminal Application")
                    .font(.headline)

                HStack(spacing: 10) {
                    if let icon = status.selectedTerminalIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "terminal")
                            .font(.title2)
                            .accessibilityHidden(true)
                    }
                    if let selected = status.selectedTerminal {
                        Text(selected.title)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(selected.applicationPath ?? selected.title)
                    } else {
                        Text("No Terminal Application Selected")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Choose Terminal Application…") {
                        Task { await status.chooseTerminalApplication() }
                    }
                    .disabled(status.isChoosingTerminal)
                    .accessibilityIdentifier("choose-terminal-application")
                }

                if let error = status.terminalPreferenceError {
                    Text(error)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                } else if status.selectedTerminal != nil, status.selectedTerminalIcon == nil {
                    Text("The selected terminal application could not be found. Choose it again.")
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Changes are saved automatically and apply immediately in Finder.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.callout)

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
    @Published private(set) var selectedTerminal: TerminalApplication?
    @Published private(set) var terminalPreferenceError: String?
    @Published private(set) var selectedTerminalIcon: NSImage?
    @Published private(set) var isChoosingTerminal = false

    /// Refreshes the system-owned extension state when the app becomes active or the user requests it.
    func refresh() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
        do {
            displaySelection(try TerminalPreferences.load())
            terminalPreferenceError = nil
        } catch {
            selectedTerminal = nil
            selectedTerminalIcon = nil
            terminalPreferenceError = error.localizedDescription
        }
    }

    /// Chooses any application bundle with the system panel; cancellation keeps the saved preference intact.
    func chooseTerminalApplication() async {
        guard !isChoosingTerminal else { return }
        isChoosingTerminal = true
        defer { isChoosingTerminal = false }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.treatsFilePackagesAsDirectories = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowsOtherFileTypes = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.title = NSLocalizedString("Choose Terminal Application…", comment: "Terminal app chooser title")
        panel.prompt = NSLocalizedString("Choose", comment: "Terminal app chooser confirmation")
        panel.message = NSLocalizedString("Choose the terminal application to open folders from Finder.", comment: "Terminal app chooser instructions")
        let response = await withCheckedContinuation { continuation in
            panel.begin { continuation.resume(returning: $0) }
        }
        guard response == .OK, let applicationURL = panel.url else { return }

        do {
            let application = try TerminalApplication(applicationURL: applicationURL)
            try TerminalPreferences.save(application)
            displaySelection(application)
            terminalPreferenceError = nil
        } catch {
            terminalPreferenceError = error.localizedDescription
        }
    }

    /// Shows the saved app and its actual icon without replacing a missing app with another terminal.
    private func displaySelection(_ application: TerminalApplication) {
        selectedTerminal = application
        var installedURL: URL?
        if let path = application.applicationPath {
            let applicationURL = URL(fileURLWithPath: path, isDirectory: true)
            if (try? TerminalApplication(applicationURL: applicationURL)) != nil {
                installedURL = applicationURL
            }
        } else {
            installedURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: application.bundleIdentifier)
        }
        selectedTerminalIcon = installedURL.map { NSWorkspace.shared.icon(forFile: $0.path) }
    }
}
