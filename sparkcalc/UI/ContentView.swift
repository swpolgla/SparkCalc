import SwiftUI

/// Root view hosting the calculator and the sheet tab bar.
///
/// Displays all sheets in a ZStack, hiding inactive sheets so their text views
/// (and undo history) remain alive across tab switches. Keyboard shortcuts
/// for tab management are attached to invisible buttons that participate in
/// the responder chain.
struct ContentView: View {
    @StateObject private var store = SheetStore()

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(store.sheets) { sheet in
                    let isActive = store.activeSheetId == sheet.id
                    CalculatorView(sheet: sheet, isActive: isActive)
                        .opacity(isActive ? 1 : 0)
                        .allowsHitTesting(isActive)
                }
            }

            Divider()

            TabBarView(store: store)
                .frame(height: 32)
                .background(.ultraThinMaterial)
        }
        .frame(minWidth: 300, minHeight: 300)
        // Invisible shortcut buttons — scoped to this window's responder chain.
        .overlay(
            VStack {
                Button(action: { store.addSheet() }) {
                    EmptyView()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button(action: {
                    if let id = store.activeSheetId {
                        store.removeSheet(id: id)
                    }
                }) {
                    EmptyView()
                }
                .keyboardShortcut("w", modifiers: .command)

                ForEach(1..<10) { num in
                    Button(action: {
                        let idx = num - 1
                        if idx < store.sheets.count {
                            store.activateSheet(id: store.sheets[idx].id)
                        }
                    }) {
                        EmptyView()
                    }
                    .keyboardShortcut(.init(Character(String(num))), modifiers: .command)
                }
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeSettings())
}