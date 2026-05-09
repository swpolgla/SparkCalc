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
    @ObservedObject var sheet: Sheet
    var isActive: Bool

    @State private var textViewRef: GrowingTextView?

    private let editorFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private let answerColumnWidth: CGFloat = 120

    public var lines: [String] {
        sheet.inputText.components(separatedBy: "\n")
    }

    var body: some View {
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
                        let equation_answers: [String] = sheet.engine.evaluate(lines: lines)
                        ForEach(equation_answers.enumerated(), id: \.offset) { index, line in
                            let height = index < sheet.lineHeights.count ? sheet.lineHeights[index] : 17
                            Text(line)
                                .font(Font(editorFont))
                                .foregroundStyle(.green.opacity(1))
                                .padding(.horizontal, 8)
                                .frame(height: height, alignment: .bottom)
                        }
                        Spacer()
                    }
                    .frame(width: answerColumnWidth, alignment: .trailing)
                }
                .frame(maxWidth: geo.size.width, minHeight: geo.size.height, alignment: .topLeading)
            }
        }
        .frame(minWidth: 300, minHeight: 300)
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
        .environmentObject(ThemeSettings())
}
