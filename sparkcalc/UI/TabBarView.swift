import SwiftUI
import UniformTypeIdentifiers

/// Tab bar for switching between calculator sheets.
///
/// Displays tabs left-aligned with an active-state indicator. Each tab can be
/// double-clicked to rename. A close button (×) appears on any tab when hovered
/// and is highlighted when directly hovered. A "+" button to the right of the
/// tabs creates a new sheet. Tabs support drag-to-reorder with live visual
/// feedback: each tab is split into left/right drop halves. Hovering over the
/// left half of a tab shows an indicator at its leading edge; hovering over the
/// right half shows an indicator at its trailing edge (or the next tab’s leading
/// edge, which is physically the same location).
struct TabBarView: View {
    var store: SheetStore

    @State private var renamingSheetId: UUID?
    @State private var renameText: String = ""
    @State private var hoveredSheetId: UUID?
    @State private var hoveredCloseSheetId: UUID?
    @State private var isAddButtonHovered: Bool = false
    @State private var dropTargetIndex: Int?
    @FocusState private var renameFieldIsFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(store.sheets.enumerated()), id: \.element.id) { index, sheet in
                        tabView(for: sheet, at: index)
                    }
                }
                .padding(.horizontal, 8)
                .animation(.easeOut(duration: 0.1), value: dropTargetIndex)
                .animation(.snappy, value: store.sheets.map(\.id))
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
    private func tabView(for sheet: Sheet, at index: Int) -> some View {
        let isActive = store.activeSheetId == sheet.id
        let isHovered = hoveredSheetId == sheet.id
        let isLast = index == store.sheets.count - 1

        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive ? Color.accentColor.opacity(0.15) : (isHovered ? Color.accentColor.opacity(0.05) : Color.clear))

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
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .overlay(
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.clear)
                    .onDrop(of: [.text], delegate: TabDropDelegate(
                        targetIndex: index,
                        store: store,
                        dropTargetIndex: $dropTargetIndex
                    ))
                Rectangle()
                    .fill(Color.clear)
                    .onDrop(of: [.text], delegate: TabDropDelegate(
                        targetIndex: index + 1,
                        store: store,
                        dropTargetIndex: $dropTargetIndex
                    ))
            }
        )
        .overlay(alignment: .leading) {
            if dropTargetIndex == index {
                indicatorLine
            }
        }
        .overlay(alignment: .trailing) {
            if dropTargetIndex == store.sheets.count && isLast {
                indicatorLine
            }
        }
        .onDrag {
            NSItemProvider(object: sheet.id.uuidString as NSString)
        } preview: {
            Text(sheet.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .onHover { hovering in
            hoveredSheetId = hovering ? sheet.id : nil
        }
    }

    private var indicatorLine: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(width: 2)
            .clipShape(RoundedRectangle(cornerRadius: 1))
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

private struct TabDropDelegate: DropDelegate {
    let targetIndex: Int
    let store: SheetStore
    @Binding var dropTargetIndex: Int?

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.plainText.identifier])
    }

    func dropEntered(info: DropInfo) {
        dropTargetIndex = targetIndex
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if dropTargetIndex == targetIndex {
            dropTargetIndex = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }

        itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
            guard let data = data as? Data,
                  let idString = String(data: data, encoding: .utf8),
                  let draggedId = UUID(uuidString: idString) else { return }

            DispatchQueue.main.async {
                withAnimation(.snappy) {
                    store.moveSheet(id: draggedId, toBaseIndex: targetIndex)
                }
                dropTargetIndex = nil
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
