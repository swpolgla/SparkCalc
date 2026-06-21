import SwiftUI

/// Root view hosting the calculator and the sheet tab bar.
///
/// Displays all sheets in a ZStack, hiding inactive sheets so their text views
/// (and undo history) remain alive across tab switches. Keyboard shortcuts
/// for tab management are attached to invisible buttons that participate in
/// the responder chain.
struct ContentView: View {
    @Environment(SheetStore.self) private var store

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
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    ContentView()
        .environment(SheetStore())
        .environment(ThemeSettings())
}
