import SwiftUI

/// Root view hosting the calculator and the sheet tab bar.
///
/// Displays the active sheet's input/output area above a row of tabs.
/// Keyboard shortcuts for tab management are attached to invisible buttons
/// that participate in the responder chain so they naturally scope to the
/// key window.
struct ContentView: View {
    @StateObject private var store = SheetStore()

    var body: some View {
        VStack(spacing: 0) {
            if let activeSheet = store.sheets.first(where: { $0.id == store.activeSheetId }) {
                CalculatorView(sheet: activeSheet)
                    .id(activeSheet.id) // Force full recreation on sheet switch
            } else {
                Color.clear
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
}
