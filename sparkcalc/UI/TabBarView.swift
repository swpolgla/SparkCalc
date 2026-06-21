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
///
/// When tabs overflow the visible width, scroll chevron buttons (`<` / `>`)
/// appear at the leading/trailing edges of the scroll area, allowing mouse and
/// keyboard users to reveal hidden tabs. One click scrolls exactly one hidden
/// tab into view.
struct TabBarView: View {
    var store: SheetStore

    @State private var renamingSheetId: UUID?
    @State private var renameText: String = ""
    @State private var hoveredSheetId: UUID?
    @State private var hoveredCloseSheetId: UUID?
    @State private var isAddButtonHovered: Bool = false
    @State private var dropTargetIndex: Int?
    @State private var tabFrames: [UUID: CGRect] = [:]
    @State private var scrollContainerWidth: CGFloat = 0
    @State private var sheetToDelete: UUID?
    @FocusState private var renameFieldIsFocused: Bool

    private var showLeadingChevron: Bool {
        tabFrames.values.contains { $0.maxX <= 0 }
    }

    private var showTrailingChevron: Bool {
        guard scrollContainerWidth > 0 else { return false }
        return tabFrames.values.contains { $0.minX >= scrollContainerWidth }
    }

    var body: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 0) {
                if showLeadingChevron {
                    scrollChevron(direction: .left) {
                        scrollToPrevious(using: proxy)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(store.sheets.enumerated()), id: \.element.id) { index, sheet in
                            tabView(for: sheet, at: index)
                                .id(sheet.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .animation(.easeOut(duration: 0.1), value: dropTargetIndex)
                    .animation(.snappy, value: store.sheets.map(\.id))
                }
                .coordinateSpace(name: "tabScrollView")
                .onPreferenceChange(TabFramePreferenceKey.self) { frames in
                    tabFrames = frames
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { scrollContainerWidth = geo.size.width }
                            .onChange(of: geo.size.width) { _, newWidth in scrollContainerWidth = newWidth }
                    }
                )

                if showTrailingChevron {
                    scrollChevron(direction: .right) {
                        scrollToNext(using: proxy)
                    }
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
                .accessibilityLabel("New sheet")
                .padding(.trailing, 8)
                .onHover { hovering in
                    isAddButtonHovered = hovering
                }

                Spacer(minLength: 0)
            }
            .onChange(of: store.activeSheetId) { _, newValue in
                if let newValue {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(newValue, anchor: .leading)
                    }
                }
            }
            .confirmationDialog(
                "Delete this sheet?",
                isPresented: Binding(
                    get: { sheetToDelete != nil },
                    set: { if !$0 { sheetToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let id = sheetToDelete { store.removeSheet(id: id) }
                    sheetToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    sheetToDelete = nil
                }
            } message: {
                Text("This sheet contains calculations that will be lost.")
            }
        }
    }

    // MARK: - Scroll Chevron

    private func scrollChevron(direction: ChevronDirection, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: direction == .left ? "chevron.left" : "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 20, height: 32)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(direction == .left ? "Scroll tabs left" : "Scroll tabs right")
        .accessibilityLabel(direction == .left ? "Scroll tabs left" : "Scroll tabs right")
    }

    private enum ChevronDirection {
        case left, right
    }

    private func scrollToPrevious(using proxy: ScrollViewProxy) {
        guard let target = store.sheets.last(where: { tab in
            guard let frame = tabFrames[tab.id] else { return false }
            return frame.maxX <= 0
        }) else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(target.id, anchor: .leading)
        }
    }

    private func scrollToNext(using proxy: ScrollViewProxy) {
        guard scrollContainerWidth > 0,
              let target = store.sheets.first(where: { tab in
                  guard let frame = tabFrames[tab.id] else { return false }
                  return frame.minX >= scrollContainerWidth
              }) else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(target.id, anchor: .trailing)
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
                    Button {
                        store.activateSheet(id: sheet.id)
                    } label: {
                        Text(sheet.name)
                            .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sheet \(sheet.name)")
                    .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
                    .onDoubleClick {
                        renamingSheetId = sheet.id
                        renameText = sheet.name
                    }
                }

                if isActive || isHovered {
                    Button(action: {
                        if sheet.inputText.isEmpty {
                            store.removeSheet(id: sheet.id)
                        } else {
                            sheetToDelete = sheet.id
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 14, height: 14)
                            .background(hoveredCloseSheetId == sheet.id ? Color(NSColor.secondaryLabelColor) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .opacity(hoveredCloseSheetId == sheet.id ? 1 : 0.5)
                    .help("Close sheet")
                    .accessibilityLabel("Close sheet")
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
            if dropTargetIndex == store.sheets.count, isLast {
                indicatorLine
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: TabFramePreferenceKey.self,
                        value: [sheet.id: geo.frame(in: .named("tabScrollView"))]
                    )
            }
        )
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

    private func renameField(for sheet: Sheet) -> some View {
        TextField("Sheet name", text: $renameText, onCommit: {
            store.renameSheet(id: sheet.id, to: renameText)
            renamingSheetId = nil
        })
        .font(.system(size: 12))
        .textFieldStyle(.plain)
        .frame(width: 100)
        .focused($renameFieldIsFocused)
        .onExitCommand {
            renamingSheetId = nil
        }
        .onAppear {
            renameFieldIsFocused = true
        }
    }
}

// MARK: - Tab Frame Tracking

private struct TabFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] {
        [:]
    }

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
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

    func dropEntered(info _: DropInfo) {
        dropTargetIndex = targetIndex
    }

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info _: DropInfo) {
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
                    store.moveSheet(id: draggedId, to: targetIndex)
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
        simultaneousGesture(
            TapGesture(count: 2)
                .onEnded { _ in action() }
        )
    }
}
