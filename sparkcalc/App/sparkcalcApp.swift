import SwiftUI

/// Application entry point.
/// Creates a single resizable window containing the main calculator view.
@main
struct sparkcalcApp: App {
    @StateObject private var themeSettings = ThemeSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeSettings)
                .frame(minWidth: 300, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        }
        .defaultSize(width: 550, height: 550)
        .windowResizability(.contentMinSize)

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(themeSettings)
        }
        #endif
    }
}
