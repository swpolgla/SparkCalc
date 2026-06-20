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
                            AnswerLineView(
                                answer: line,
                                height: height,
                                font: Font(editorFont),
                                color: Color(nsColor: themeSettings.theme.answer)
                            )
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
        .onChange(of: sheet.inputText) { _, _ in
            sheet.updateAnswers()
        }
        .onChange(of: isActive) { _, _ in
            if isActive, let tv = textViewRef {
                DispatchQueue.main.async {
                    tv.window?.makeFirstResponder(tv)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Answer Line View

/// A single line in the answer column that supports tap-to-copy.
///
/// Displays the formatted result and provides hover affordance, haptic feedback,
/// and a brief visual flash when the user taps to copy the value to the pasteboard.
/// Empty lines are non-interactive.
private struct AnswerLineView: View {
    let answer: String
    let height: CGFloat
    let font: Font
    let color: Color

    @State private var isHovered = false
    @State private var isFlashing = false

    private var isCopyable: Bool { !answer.isEmpty }

    var body: some View {
        HStack {
            Spacer()
            Text(answer)
                .font(font)
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    isFlashing
                        ? Color(nsColor: .selectedContentBackgroundColor)
                        : (isHovered && isCopyable ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.15) : Color.clear)
                )
                .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    guard isCopyable else { return }
                    copyToClipboard(answer)
                    triggerClickFeedback()
                }
                .onHover { hovering in
                    isHovered = hovering
                    if hovering && isCopyable {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .help(isCopyable ? "Copy to clipboard" : "")
                .accessibilityLabel(isCopyable ? "Answer: \(answer)" : "Empty answer")
                .accessibilityAddTraits(isCopyable ? .isButton : [])
                .accessibilityAction(.default) {
                    guard isCopyable else { return }
                    copyToClipboard(answer)
                    triggerClickFeedback()
                }
        }
        .frame(height: height, alignment: .bottom)
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func triggerClickFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .generic,
            performanceTime: .default
        )

        withAnimation(.easeInOut(duration: 0.08)) {
            isFlashing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isFlashing = false
            }
        }
    }
}

#Preview {
    CalculatorView(sheet: Sheet(name: "Preview"), isActive: true)
        .environment(ThemeSettings())
}
