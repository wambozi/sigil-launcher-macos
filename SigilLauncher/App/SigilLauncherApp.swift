import SwiftUI

@main
struct SigilLauncherApp: App {
    @StateObject private var vmManager = VMManager()

    var body: some Scene {
        WindowGroup {
            LauncherView()
                .environmentObject(vmManager)
        }
        .windowResizability(.contentSize)

        Settings {
            ConfigurationView()
                .environmentObject(vmManager)
        }
    }
}
