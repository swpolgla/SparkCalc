import SwiftUI
import AppKit

// MARK: - Main View

/// The root calculator view.
///
/// Displays a split-pane layout: an editable input area on the left and
/// live-evaluated answers on the right. Both panes scroll together line-by-line.
/// The engine and highlighter are instantiated once per view lifetime and shared
/// across the UI hierarchy.
struct CalculatorView: View {
    @State private var inputText: String = ""
    @State private var lineHeights: [CGFloat] = [17]
    @State private var textViewRef: GrowingTextView?

    private let editorFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private let answerColumnWidth: CGFloat = 120

    // Shared engine and highlighter — created once per view lifetime.
    // Stored as `let` because they are reference types that outlive the view body.
    private let engine: CalculatorEngine
    private let highlighter: SyntaxHighlighter

    init() {
        let sharedEngine = CalculatorEngine()
        self.engine = sharedEngine
        self.highlighter = SyntaxHighlighter(engine: sharedEngine)
    }

    public var lines: [String] {
        inputText.components(separatedBy: "\n")
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                HStack(alignment: .top, spacing: 0) {

                    // ── Left: expanding text editor ──────────────────────
                    VStack(spacing: 0) {
                        ExpandingTextEditor(
                            text: $inputText,
                            font: editorFont,
                            lineHeights: $lineHeights,
                            syntaxHighlighter: highlighter,
                            onSetup: { textViewRef = $0 }
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
                        let equation_answers: [String] = engine.evaluate(lines: lines)
                        ForEach(equation_answers.enumerated(), id: \.offset) { index, line in
                            let height = index < lineHeights.count ? lineHeights[index] : 17
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
    }
}

#Preview {
    CalculatorView()
}
