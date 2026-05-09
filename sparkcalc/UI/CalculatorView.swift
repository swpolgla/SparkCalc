import SwiftUI
import AppKit

// MARK: - Main View
struct CalculatorView: View {
    @State private var inputText: String = ""
    @State private var lineHeights: [CGFloat] = [17]
    @State private var textViewRef: GrowingTextView?

    private let editorFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private let answerColumnWidth: CGFloat = 120

    // Shared engine and highlighter — created once
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
