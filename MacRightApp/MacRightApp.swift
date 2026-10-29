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
        .defaultSize(width: 480, height: 300)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                Text("MacRight")
                    .font(.title2.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 16) {
                settingsGroup("Finder Extension") {
                    HStack(spacing: 12) {
                        Label(LocalizedStringKey(status.extensionEnabled ? "Enabled" : "Setup Required"),
                              systemImage: status.extensionEnabled ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(status.extensionEnabled ? Color.primary : Color.orange)
                        Spacer()
                        if status.extensionEnabled {
                            extensionSettingsButton.buttonStyle(.bordered)
                        } else {
                            extensionSettingsButton.buttonStyle(.borderedProminent)
                        }
                    }
                    Text(LocalizedStringKey(status.extensionEnabled
                         ? "Right-click in Finder or on your desktop to use MacRight."
                         : "Open extension settings and enable MacRight, then return here to check its status."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                settingsGroup("Terminal Application") {
                    HStack(spacing: 10) {
                        if let icon = status.selectedTerminalIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "terminal")
                                .frame(width: 24, height: 24)
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
                        Spacer(minLength: 12)
                        Button("Choose…") {
                            Task { await status.chooseTerminalApplication() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(status.isChoosingTerminal)
                        .accessibilityLabel("Choose Terminal Application…")
                        .accessibilityIdentifier("choose-terminal-application")
                    }
                    if let error = status.terminalPreferenceError {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.callout)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if status.selectedTerminal != nil, status.selectedTerminalIcon == nil {
                        Label("The selected terminal application could not be found. Choose it again.",
                              systemImage: "exclamationmark.circle")
                            .font(.callout)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: status.refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            status.refresh()
        }
    }

    private var extensionSettingsButton: some View {
        Button("Extension Settings…") {
            FIFinderSyncController.showExtensionManagementInterface()
        }
    }

    /// Groups each setting with its action and feedback on an opaque, appearance-aware surface.
    private func settingsGroup<Content: View>(
        _ title: LocalizedStringKey, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 10, content: content)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
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
        selectedTerminalIcon = (try? application.installedURL()).map {
            NSWorkspace.shared.icon(forFile: $0.path)
        }
    }
}
