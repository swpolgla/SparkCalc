import AppKit
@testable import sparkcalc
import Testing

@MainActor
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

    // MARK: - Autocomplete ghost vs. user typing

    @Test func discardAutocompleteAfterTypingThroughGhostKeepsUserText() {
        let textView = GrowingTextView()
        textView.autocompleteEnabled = true
        textView.autocompleteEngine = CalculatorEngine()
        textView.autocompleteMinimumPrefixLength = 2
        textView.allowsUndo = true
        textView.string = "total = 5\ntota"
        textView.setSelectedRange(NSRange(location: 14, length: 0))

        let suggestion = AutocompleteSuggestion(name: "total", detailText: "Variable", kind: .variable)
        textView.showAutocomplete(suggestions: [suggestion], range: NSRange(location: 10, length: 4))

        #expect(textView.string == "total = 5\ntotal")
        let ghostRange = textView.selectedRange()
        #expect(ghostRange == NSRange(location: 14, length: 1))

        textView.ghostEditConsumed = true
        textView.textStorage?.replaceCharacters(in: ghostRange, with: "l")
        textView.setSelectedRange(NSRange(location: 15, length: 0))

        textView.discardAutocomplete()

        #expect(textView.string == "total = 5\ntotal")
        #expect(textView.selectedRange() == NSRange(location: 15, length: 0))
        #expect(textView.ghostEditConsumed == false)
    }

    @Test func discardAutocompleteAfterSelectionMoveRemovesGhostStillPresent() {
        let textView = GrowingTextView()
        textView.autocompleteEnabled = true
        textView.autocompleteEngine = CalculatorEngine()
        textView.allowsUndo = true
        textView.string = "total = 5\ntot"
        textView.setSelectedRange(NSRange(location: 13, length: 0))

        let suggestion = AutocompleteSuggestion(name: "total", detailText: "Variable", kind: .variable)
        textView.showAutocomplete(suggestions: [suggestion], range: NSRange(location: 10, length: 3))
        #expect(textView.string == "total = 5\ntotal")
        #expect(textView.selectedRange() == NSRange(location: 13, length: 2))

        textView.setSelectedRange(NSRange(location: 5, length: 0))
        textView.discardAutocomplete()

        #expect(textView.string == "total = 5\ntot")
        #expect(textView.selectedRange() == NSRange(location: 5, length: 0))
    }

    @Test func pressingEscapeAfterGhostInstallClearsAutocomplete() throws {
        let textView = GrowingTextView()
        textView.autocompleteEnabled = true
        textView.autocompleteEngine = CalculatorEngine()
        textView.allowsUndo = true
        textView.string = "total = 5\ntot"
        textView.setSelectedRange(NSRange(location: 13, length: 0))

        let suggestion = AutocompleteSuggestion(name: "total", detailText: "Variable", kind: .variable)
        textView.showAutocomplete(suggestions: [suggestion], range: NSRange(location: 10, length: 3))
        #expect(textView.string == "total = 5\ntotal")

        let escapeEvent = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "\u{1B}",
            charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false,
            keyCode: 53
        ))
        textView.keyDown(with: escapeEvent)

        #expect(textView.string == "total = 5\ntot")
        #expect(textView.selectedRange() == NSRange(location: 13, length: 0))
    }
}
