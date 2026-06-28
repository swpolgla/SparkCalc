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

    /// Simulates the reported crash: a variable is defined on an earlier line,
    /// the user types a partial prefix, the ghost completion is installed, then
    /// finishes typing the variable name one keystroke at a time instead of
    /// accepting the suggestion with Tab/Return.
    ///
    /// Before the fix, `discardAutocomplete` would delete the range stored in
    /// `activeAutocompleteSelection` even though the user had just typed into
    /// it. The deletion re-entered NSTextStorage's `endEditing` pipeline and
    /// raised `NSRangeException` from `ensureLayoutForTextContainer:`.
    ///
    /// Here we drive the same logic the production shouldChangeText delegate
    /// hook does (set `ghostEditConsumed = true` when an edit touches the ghost
    /// range) and `discardAutocomplete` afterwards, asserting the user's typed
    /// letter survives.
    @Test func discardAutocompleteAfterTypingThroughGhostKeepsUserText() {
        let textView = GrowingTextView()
        textView.autocompleteEnabled = true
        textView.autocompleteEngine = CalculatorEngine()
        textView.autocompleteMinimumPrefixLength = 2
        textView.allowsUndo = true
        textView.string = "total = 5\ntota"
        textView.setSelectedRange(NSRange(location: 14, length: 0))

        // Drive the same path the Coordinator uses after typing "tota".
        let suggestion = AutocompleteSuggestion(name: "total", detailText: "Variable", kind: .variable)
        textView.showAutocomplete(suggestions: [suggestion], range: NSRange(location: 10, length: 4))

        // The ghost "l" should be installed and selected.
        #expect(textView.string == "total = 5\ntotal")
        let ghostRange = textView.selectedRange()
        #expect(ghostRange == NSRange(location: 14, length: 1))

        // Simulate the user typing the final "l" through the ghost selection.
        // AppKit calls shouldChangeTextIn BEFORE mutating the storage, which
        // is what sets `ghostEditConsumed` in the production Coordinator hook.
        textView.ghostEditConsumed = true
        textView.textStorage?.replaceCharacters(in: ghostRange, with: "l")
        textView.setSelectedRange(NSRange(location: 15, length: 0))

        // The discard would have been triggered by textViewDidChangeSelection.
        textView.discardAutocomplete()

        // The user's "l" is preserved; the ghost was not re-deleted.
        #expect(textView.string == "total = 5\ntotal")
        #expect(textView.selectedRange() == NSRange(location: 15, length: 0))
        #expect(textView.ghostEditConsumed == false)
    }

    /// Verifies the legitimate discard path (selection moved without an edit)
    /// still removes the suggestion. This guards against a regression that
    /// suppressed all discards rather than just typing-induced ones.
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

        // Move the caret elsewhere without any text edit (arrow-key / click).
        textView.setSelectedRange(NSRange(location: 5, length: 0))
        textView.discardAutocomplete()

        // Ghost removed: text reverts to the prefix the user typed.
        #expect(textView.string == "total = 5\ntot")
        #expect(textView.selectedRange() == NSRange(location: 5, length: 0))
    }

    /// Escape while a ghost is installed should cancel cleanly: collapse the
    /// selection, remove the ghost text, and never re-enter NSTextStorage edit
    /// dispatch. Drives the same keyDown branch the production Escape handler
    /// uses (keyCode 53) with a synthetic event.
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

        // Synthesize an Escape key event and route through the public keyDown
        // override. NSTextView lacks a window in a unit test, so this never
        // enters the input-method pipeline; it goes directly to the handler.
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
        // Cursor collapses to where the ghost started (end of "tot").
        #expect(textView.selectedRange() == NSRange(location: 13, length: 0))
    }
}
