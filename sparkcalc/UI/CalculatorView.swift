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

    static let defaultFontSize: CGFloat = 14
    private let editorFont = NSFont.monospacedSystemFont(ofSize: Self.defaultFontSize, weight: .regular)
    private let answerColumnWidth: CGFloat = 120

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

                    Divider()

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

                            Divider().hidden()

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
