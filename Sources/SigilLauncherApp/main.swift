// Thin wrapper — the real entry point lives at SigilLauncher/App/SigilLauncherApp.swift
// and is compiled as part of SigilLauncherLib. This file exists only so SPM has a
// non-overlapping executable target path.
import SwiftUI
import SigilLauncherLib

@main
struct SigilLauncherAppEntry: App {
    @StateObject private var vmManager = VMManager()
    @State private var showWizard: Bool

    init() {
        let profileExists = FileManager.default.fileExists(
            atPath: LauncherProfile.settingsURL.path
        )
        _showWizard = State(initialValue: !profileExists)
    }

    var body: some Scene {
        WindowGroup {
            if showWizard {
                SetupWizard(imageBuilder: vmManager.imageBuilder) { profile in
                    vmManager.updateProfile(profile)
                    showWizard = false
                }
            } else {
                LauncherView()
                    .environmentObject(vmManager)
            }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Sigil Launcher") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        NSApplication.AboutPanelOptionKey.applicationName: "Sigil Launcher",
                        NSApplication.AboutPanelOptionKey.applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1",
                    ])
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Preferences...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            ConfigurationView()
                .environmentObject(vmManager)
        }
    }
}
