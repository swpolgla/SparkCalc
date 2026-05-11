import SwiftUI

/// Application entry point.
/// Creates a single resizable window containing the main calculator view.
@main
struct SparkcalcApp: App {
    @State private var store = SheetStore()
    @State private var themeSettings = ThemeSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(themeSettings)
                .frame(minWidth: 300, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        }
        .defaultSize(width: 550, height: 550)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Sheet") {
                    store.addSheet()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button("Close Sheet") {
                    if let id = store.activeSheetId {
                        store.removeSheet(id: id)
                    }
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
            }

            CommandGroup(after: .windowArrangement) {
                Button("Previous Sheet") {
                    store.activatePreviousSheet()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Button("Next Sheet") {
                    store.activateNextSheet()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(themeSettings)
        }
        #endif
    }
}
