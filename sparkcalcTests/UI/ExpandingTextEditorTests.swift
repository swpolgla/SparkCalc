import AppKit
@testable import sparkcalc
import Testing

struct ExpandingTextEditorTests {
    @Test func programmaticTextReplacementUpdatesEditorAndClearsUndoHistory() {
        let textView = GrowingTextView()
        let undoManager = UndoManager()
        textView.sheetUndoManager = undoManager
        textView.allowsUndo = true
        textView.string = "old text"

        let highlighter = SyntaxHighlighter(engine: CalculatorEngine())
        highlighter.textView = textView
        textView.textStorage?.delegate = highlighter

        ExpandingTextEditor.setEditorText(
            textView,
            "1 + 1",
            registerUndo: false,
            syntaxHighlighter: highlighter
        )

        #expect(textView.string == "1 + 1")
        #expect(undoManager.canUndo == false)
    }
}
