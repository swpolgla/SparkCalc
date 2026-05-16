import SwiftUI
import AppKit

// MARK: - Main View

/// The calculator view for a single sheet.
///
/// Displays a split-pane layout: an editable input area on the left and
/// live-evaluated answers on the right. Both panes scroll together line-by-line.
/// The engine and highlighter are taken from the provided `Sheet` so each sheet
/// is fully isolated.
struct CalculatorView: View {
    var sheet: Sheet
    var isActive: Bool
    @Environment(ThemeSettings.self) var themeSettings

    @State private var textViewRef: GrowingTextView?
    @State private var dividerDragStartFraction: CGFloat?

    static let defaultFontSize: CGFloat = 14
    private let editorFont = NSFont.monospacedSystemFont(ofSize: Self.defaultFontSize, weight: .regular)

    private let minInputWidth: CGFloat = 150
    private let minOutputWidth: CGFloat = 80
    private let dividerHitWidth: CGFloat = 8

    private var lines: [String] {
        sheet.inputText.components(separatedBy: "\n")
    }

    private func alternatingRowBackground(for index: Int) -> Color {
        guard index % 2 == 1 else { return Color.clear }
        let colors = NSColor.alternatingContentBackgroundColors
        guard colors.count > 1 else { return Color.clear }
        return Color(nsColor: colors[1])
    }

    var body: some View {
        @Bindable var sheet = sheet
        GeometryReader { geo in
            let maxOutputWidth = max(minOutputWidth, geo.size.width - minInputWidth - dividerHitWidth)
            let answerColumnWidth = max(minOutputWidth, min(maxOutputWidth, geo.size.width * sheet.answerColumnFraction))

            ScrollView {
                HStack(alignment: .top, spacing: 0) {

                    // ── Left: expanding text editor ──────────────────────
                    VStack(spacing: 0) {
                        ExpandingTextEditor(
                            text: $sheet.inputText,
                            font: editorFont,
                            lineHeights: $sheet.lineHeights,
                            syntaxHighlighter: sheet.highlighter,
                            undoManager: sheet.undoManager,
                            isActive: isActive,
                            onSetup: { tv in
                                textViewRef = tv
                                if isActive {
                                    tv.window?.makeFirstResponder(tv)
                                }
                            }
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)

                        // Tappable fill: clicking below the last line focuses
                        // the editor and places the cursor at the end.
                        Color.clear
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard let tv = textViewRef else { return }
                                tv.window?.makeFirstResponder(tv)
                                tv.setSelectedRange(NSRange(location: tv.string.utf16.count, length: 0))
                            }
                    }
                    .frame(maxWidth: .infinity)

                    ZStack {
                        Rectangle()
                            .fill(Color(nsColor: .separatorColor))
                            .frame(width: 1)
                        VStack(spacing: 2) {
                            ForEach(0..<3) { _ in
                                Capsule()
                                    .fill(Color(nsColor: .separatorColor))
                                    .frame(width: 4, height: 1)
                            }
                        }
                    }
                    .frame(width: dividerHitWidth)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .global)
                            .onChanged { value in
                                if dividerDragStartFraction == nil {
                                    dividerDragStartFraction = sheet.answerColumnFraction
                                }
                                let deltaFraction = value.translation.width / geo.size.width
                                // Invert sign because DragGesture translation is opposite to the
                                // desired splitter direction on macOS.
                                let newFraction = dividerDragStartFraction! - deltaFraction
                                let minFraction = minOutputWidth / geo.size.width
                                let maxFraction = maxOutputWidth / geo.size.width
                                sheet.answerColumnFraction = max(minFraction, min(maxFraction, newFraction))
                            }
                            .onEnded { _ in
                                dividerDragStartFraction = nil
                            }
                    )

                    // ── Right: answer column ─────────────────────────────
                    VStack(alignment: .trailing, spacing: 0) {
                        let equationAnswers = sheet.answers
                        ForEach(equationAnswers.enumerated(), id: \.offset) { index, line in
                            let height = index < sheet.lineHeights.count ? sheet.lineHeights[index] : Sheet.defaultLineHeight
                            Text(line)
                                .font(Font(editorFont))
                                .foregroundStyle(Color(nsColor: themeSettings.theme.answer))
                                .padding(.horizontal, 8)
                                .frame(height: height, alignment: .bottom)
                        }
                        Spacer()
                    }
                    .frame(width: answerColumnWidth, alignment: .trailing)
                }
                .frame(maxWidth: geo.size.width, minHeight: geo.size.height, alignment: .topLeading)
                .background(alignment: .topLeading) {
                    if themeSettings.alternatingLineBackgroundsEnabled {
                        HStack(spacing: 0) {
                            VStack(spacing: 0) {
                                ForEach(sheet.lineHeights.indices, id: \.self) { index in
                                    alternatingRowBackground(for: index)
                                        .opacity(themeSettings.lineTintIntensity)
                                        .frame(height: sheet.lineHeights[index])
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)

                            Color.clear.frame(width: dividerHitWidth)

                            VStack(spacing: 0) {
                                ForEach(sheet.lineHeights.indices, id: \.self) { index in
                                    alternatingRowBackground(for: index)
                                        .opacity(themeSettings.lineTintIntensity)
                                        .frame(height: sheet.lineHeights[index])
                                }
                                Spacer()
                            }
                            .frame(width: answerColumnWidth)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 300)
        .onAppear {
            sheet.updateAnswers()
        }
        .onChange(of: sheet.inputText) {
            sheet.updateAnswers()
        }
        .onChange(of: isActive) {
            if isActive, let tv = textViewRef {
                DispatchQueue.main.async {
                    tv.window?.makeFirstResponder(tv)
                }
            }
        }
    }
}

#Preview {
    CalculatorView(sheet: Sheet(name: "Preview"), isActive: true)
        .environment(ThemeSettings())
}
