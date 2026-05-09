import SwiftUI
import UniformTypeIdentifiers

/// Tab bar for switching between calculator sheets.
///
/// Displays tabs left-aligned with an active-state indicator. Each tab can be
/// double-clicked to rename. A close button (×) appears on any tab when hovered
/// and is highlighted when directly hovered. A "+" button to the right of the
/// tabs creates a new sheet. Tabs support drag-to-reorder.
struct TabBarView: View {
    @ObservedObject var store: SheetStore

    @State private var renamingSheetId: UUID?
    @State private var renameText: String = ""
    @State private var hoveredSheetId: UUID?
    @State private var hoveredCloseSheetId: UUID?
    @State private var isAddButtonHovered: Bool = false
    @FocusState private var renameFieldIsFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(store.sheets) { sheet in
                        tabView(for: sheet)
                            .onDrag {
                                NSItemProvider(object: TabBarItemProvider(sheetId: sheet.id))
                            }
                            .onDrop(of: [.text], delegate: TabDropDelegate(sheet: sheet, store: store))
                    }
                }
                .padding(.horizontal, 8)
            }

            Button(action: { store.addSheet() }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .background(isAddButtonHovered ? Color.accentColor.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("New sheet")
            .padding(.trailing, 8)
            .onHover { hovering in
                isAddButtonHovered = hovering
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Individual Tab

    @ViewBuilder
    private func tabView(for sheet: Sheet) -> some View {
        let isActive = store.activeSheetId == sheet.id
        let isHovered = hoveredSheetId == sheet.id

        HStack(spacing: 4) {
            if renamingSheetId == sheet.id {
                renameField(for: sheet)
            } else {
                Text(sheet.name)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                    .onTapGesture {
                        store.activateSheet(id: sheet.id)
                    }
                    .onDoubleClick {
                        renamingSheetId = sheet.id
                        renameText = sheet.name
                    }
            }

            if isActive || isHovered {
                Button(action: { store.removeSheet(id: sheet.id) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 14, height: 14)
                        .background(hoveredCloseSheetId == sheet.id ? Color(NSColor.secondaryLabelColor) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
                .buttonStyle(.plain)
                .opacity(hoveredCloseSheetId == sheet.id ? 1 : 0.5)
                .help("Close sheet")
                .onHover { hovering in
                    hoveredCloseSheetId = hovering ? sheet.id : nil
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isActive ? Color.accentColor.opacity(0.15) : (isHovered ? Color.accentColor.opacity(0.05) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredSheetId = hovering ? sheet.id : nil
        }
    }

    @ViewBuilder
    private func renameField(for sheet: Sheet) -> some View {
        TextField("Sheet name", text: $renameText, onCommit: {
            store.renameSheet(id: sheet.id, to: renameText)
            renamingSheetId = nil
        })
        .font(.system(size: 12))
        .textFieldStyle(.plain)
        .frame(width: 100)
        .focused($renameFieldIsFocused)
        .onAppear {
            renameFieldIsFocused = true
        }
    }
}

// MARK: - Drag & Drop Support

/// Simple item provider wrapper so we can carry a sheet ID during drag.
private class TabBarItemProvider: NSObject, NSItemProviderWriting {
    let sheetId: UUID

    init(sheetId: UUID) {
        self.sheetId = sheetId
        super.init()
    }

    static var writableTypeIdentifiersForItemProvider: [String] {
        [UTType.plainText.identifier]
    }

    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        let data = sheetId.uuidString.data(using: .utf8)
        completionHandler(data, nil)
        return nil
    }
}

private struct TabDropDelegate: DropDelegate {
    let sheet: Sheet
    let store: SheetStore

    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }

        let targetSheetId = sheet.id

        itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
            guard let data = data as? Data,
                  let idString = String(data: data, encoding: .utf8),
                  let draggedId = UUID(uuidString: idString) else { return }

            DispatchQueue.main.async {
                guard let fromIndex = store.sheets.firstIndex(where: { $0.id == draggedId }),
                      let toIndex = store.sheets.firstIndex(where: { $0.id == targetSheetId }) else { return }
                store.moveSheet(fromIndex: fromIndex, toIndex: toIndex)
            }
        }
        return true
    }
}

// MARK: - Double-click Gesture Helper

private extension View {
    func onDoubleClick(perform action: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            TapGesture(count: 2)
                .onEnded { _ in action() }
        )
    }
}