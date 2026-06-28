import AppKit
import SwiftUI

// MARK: - Growing NSTextView subclass

/// An `NSTextView` subclass that reports its height based on laid-out text.
///
/// By overriding `intrinsicContentSize`, the view pushes its container height
/// in SwiftUI rather than scrolling internally. This allows the text view to live
/// inside a shared `ScrollView` while still growing vertically with content.
class GrowingTextView: NSTextView {
    /// Per-sheet undo manager. When set, overrides the default responder-chain
    /// lookup so each sheet gets its own isolated undo/redo history.
    weak var sheetUndoManager: UndoManager?

    /// When `false` the view refuses first-responder status so hidden sheets
    /// in the ZStack cannot steal focus from the active sheet.
    var isActive: Bool = true

    /// When `false`, blocks automatic period substitution from double-space.
    var smartSubstitutionsEnabled: Bool = false

    var autocompleteEnabled: Bool = true
    var autocompleteMinimumPrefixLength: Int = 2
    weak var autocompleteEngine: CalculatorEngine?
    let autocompleteProvider = AutocompleteProvider()
    var isUpdatingAutocompleteGhost = false
    fileprivate var activeAutocompleteSelection: NSRange?
    fileprivate var activeAutocompleteRange: NSRange?
    /// Set `true` by `textView(_:shouldChangeTextIn:replacementString:)` when an
    /// incoming text edit touches the active ghost-completion range. Mutating
    /// the ghost range via the user keystroke invalidates it: `discardAutocomplete`
    /// checks this flag and skips deletion so the user's typed content survives.
    /// Without this, typing the same letter as the trailing ghost (e.g. ghost
    /// "l", user presses "l") would still pass a substring-equality check and
    /// wrongly delete the user's text.
    var ghostEditConsumed = false
    private lazy var autocompletePopup = AutocompletePopupController { [weak self] suggestion in
        self?.acceptAutocomplete(suggestion)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, cancelAutocomplete() {
            return
        }
        if event.keyCode == 125, autocompletePopup.isShown {
            if let suggestion = autocompletePopup.moveSelection(1) {
                updateAutocompleteGhost(to: suggestion)
            }
            return
        }
        if event.keyCode == 126, autocompletePopup.isShown {
            if let suggestion = autocompletePopup.moveSelection(-1) {
                updateAutocompleteGhost(to: suggestion)
            }
            return
        }
        if event.keyCode == 36, let suggestion = autocompletePopup.selectedSuggestion {
            acceptAutocomplete(suggestion)
            return
        }
        if event.keyCode == 51, deleteBackwardFromActiveAutocomplete() {
            return
        }
        if event.keyCode == 48, acceptBestAutocomplete() {
            return
        }
        super.keyDown(with: event)
    }

    override func insertCompletion(_ word: String, forPartialWordRange charRange: NSRange, movement: Int, isFinal flag: Bool) {
        let insertedWord = flag ? finalInsertionText(for: word, range: charRange) : word
        isUpdatingAutocompleteGhost = !flag
        defer { isUpdatingAutocompleteGhost = false }
        super.insertCompletion(insertedWord, forPartialWordRange: charRange, movement: movement, isFinal: flag)

        activeAutocompleteSelection = flag ? nil : selectedRange()
        activeAutocompleteRange = flag ? nil : charRange

        // A freshly installed ghost has not yet been touched by an edit; reset
        // the consumption flag so subsequent typing can mark it consumed.
        if !flag {
            ghostEditConsumed = false
        }

        guard flag, let openParen = insertedWord.firstIndex(of: "("), let closeParen = insertedWord.lastIndex(of: ")"), openParen < closeParen else { return }
        let innerStart = insertedWord.index(after: openParen).utf16Offset(in: insertedWord)
        let innerLength = closeParen.utf16Offset(in: insertedWord) - innerStart
        setSelectedRange(NSRange(location: charRange.location + innerStart, length: innerLength))
    }

    private func finalInsertionText(for word: String, range: NSRange) -> String {
        guard let engine = autocompleteEngine else { return word }
        return autocompleteProvider.suggestions(
            in: string,
            cursorLocation: NSMaxRange(range),
            engine: engine,
            minimumPrefixLength: autocompleteMinimumPrefixLength
        ).first { $0.name == word }?.insertionText ?? word
    }

    private func deleteBackwardFromActiveAutocomplete() -> Bool {
        let selected = selectedRange()
        guard let activeAutocompleteSelection,
              selected == activeAutocompleteSelection,
              selected.length > 0,
              selected.location > 0
        else { return false }

        self.activeAutocompleteSelection = nil
        activeAutocompleteRange = nil
        ghostEditConsumed = false
        autocompletePopup.close()
        let deletionRange = NSRange(location: selected.location - 1, length: selected.length + 1)
        guard shouldChangeText(in: deletionRange, replacementString: "") else { return true }
        textStorage?.replaceCharacters(in: deletionRange, with: "")
        setSelectedRange(NSRange(location: deletionRange.location, length: 0))
        didChangeText()
        return true
    }

    private func acceptBestAutocomplete() -> Bool {
        if let suggestion = autocompletePopup.selectedSuggestion {
            acceptAutocomplete(suggestion)
            return true
        }

        guard autocompleteEnabled, let engine = autocompleteEngine else { return false }

        let location = activeAutocompleteRange.map(NSMaxRange) ?? selectedRange().location
        guard let range = autocompleteProvider.completionRange(in: string, cursorLocation: location) else { return false }
        let suggestions = autocompleteProvider.suggestions(
            in: string,
            cursorLocation: location,
            engine: engine,
            minimumPrefixLength: autocompleteMinimumPrefixLength
        )
        guard let best = suggestions.first else { return false }
        acceptAutocomplete(best, range: range)
        return true
    }

    func showAutocomplete(suggestions: [AutocompleteSuggestion], range: NSRange) {
        guard let first = suggestions.first else {
            closeAutocomplete()
            return
        }

        insertCompletion(first.name, forPartialWordRange: range, movement: NSOtherTextMovement, isFinal: false)
        autocompletePopup.show(suggestions: suggestions, relativeTo: self)
    }

    func closeAutocomplete() {
        activeAutocompleteSelection = nil
        activeAutocompleteRange = nil
        ghostEditConsumed = false
        autocompletePopup.close()
    }

    func discardAutocomplete() {
        guard let ghostRange = activeAutocompleteSelection else {
            closeAutocomplete()
            return
        }

        let consumed = ghostEditConsumed
        let selection = selectedRange()
        closeAutocomplete()
        // Skip deletion if an edit already touched the ghost range. The user
        // typed through (or into) the suggestion: the range now holds user
        // content that must be preserved. Deletion when `consumed` is true
        // would also re-enter NSTextStorage's endEditing pipeline (the crash
        // root cause: NSRangeException from ensureLayout) — so do nothing.
        // When `consumed` is false, only the selection moved (without an
        // edit), so the ghost text is genuinely unwritten and must be removed.
        guard !consumed,
              ghostRange.length > 0,
              NSMaxRange(ghostRange) <= (string as NSString).length,
              shouldChangeText(in: ghostRange, replacementString: "")
        else { return }

        isUpdatingAutocompleteGhost = true
        textStorage?.replaceCharacters(in: ghostRange, with: "")
        let adjustedSelection = if NSIntersectionRange(selection, ghostRange).length > 0 {
            NSRange(location: ghostRange.location, length: 0)
        } else if selection.location >= NSMaxRange(ghostRange) {
            NSRange(
                location: selection.location - ghostRange.length,
                length: selection.length
            )
        } else {
            selection
        }
        setSelectedRange(adjustedSelection)
        didChangeText()
        isUpdatingAutocompleteGhost = false
    }

    func discardAutocompleteIfSelectionMoved() {
        guard !isUpdatingAutocompleteGhost,
              let activeAutocompleteSelection,
              selectedRange() != activeAutocompleteSelection
        else { return }
        // Defer: textViewDidChangeSelection fires synchronously inside
        // NSTextStorage endEditing / NSLayoutManager textStorage:edited:.
        // Mutating text storage here re-enters that pipeline and corrupts the
        // layout manager's in-flight glyph update, raising NSRangeException
        // ("Range out of bounds; string length N") from ensureLayout.
        let snapshot = activeAutocompleteSelection
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.activeAutocompleteSelection == snapshot,
                  selectedRange() != snapshot
            else { return }
            discardAutocomplete()
        }
    }

    private func acceptAutocomplete(_ suggestion: AutocompleteSuggestion, range: NSRange? = nil) {
        let completionRange = range ?? activeAutocompleteRange
        guard let completionRange else { return }
        activeAutocompleteSelection = nil
        activeAutocompleteRange = nil
        ghostEditConsumed = false
        autocompletePopup.close()
        insertCompletion(suggestion.name, forPartialWordRange: completionRange, movement: NSTabTextMovement, isFinal: true)
    }

    private func updateAutocompleteGhost(to suggestion: AutocompleteSuggestion) {
        guard let activeAutocompleteRange else { return }
        insertCompletion(suggestion.name, forPartialWordRange: activeAutocompleteRange, movement: NSOtherTextMovement, isFinal: false)
    }

    private func cancelAutocomplete() -> Bool {
        guard let activeAutocompleteSelection,
              selectedRange() == activeAutocompleteSelection
        else {
            autocompletePopup.close()
            return false
        }

        // Bounds guard: if the storage shrank (e.g. external edit), the stale
        // selection range may extend past the current end. Clear state without
        // mutating storage rather than triggering an NSRangeException.
        guard NSMaxRange(activeAutocompleteSelection) <= (string as NSString).length else {
            self.activeAutocompleteSelection = nil
            activeAutocompleteRange = nil
            ghostEditConsumed = false
            autocompletePopup.close()
            return true
        }
        guard shouldChangeText(in: activeAutocompleteSelection, replacementString: "") else { return true }
        textStorage?.replaceCharacters(in: activeAutocompleteSelection, with: "")
        setSelectedRange(NSRange(location: activeAutocompleteSelection.location, length: 0))
        self.activeAutocompleteSelection = nil
        activeAutocompleteRange = nil
        ghostEditConsumed = false
        autocompletePopup.close()
        didChangeText()
        return true
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        if !smartSubstitutionsEnabled,
           let text = string as? String,
           text == ". ",
           let event = NSApp.currentEvent,
           event.type == .keyDown,
           event.characters == " "
        {
            let fullString = self.string as NSString
            let loc = replacementRange.location
            let len = replacementRange.length
            if len == 1,
               loc < fullString.length,
               fullString.character(at: loc) == unichar((" " as UnicodeScalar).value)
            {
                // System is replacing the previous space with ". " — keep both spaces.
                super.insertText("  ", replacementRange: replacementRange)
            } else {
                // System is inserting ". " at the cursor — just insert the new space.
                super.insertText(" ", replacementRange: replacementRange)
            }
            return
        }
        super.insertText(string, replacementRange: replacementRange)
    }

    override var undoManager: UndoManager? {
        sheetUndoManager ?? super.undoManager
    }

    override var acceptsFirstResponder: Bool {
        isActive && super.acceptsFirstResponder
    }

    /// Intercept undo from the responder chain and route to the sheet's manager.
    @objc func undo(_: Any?) {
        sheetUndoManager?.undo()
    }

    /// Intercept redo from the responder chain and route to the sheet's manager.
    @objc func redo(_: Any?) {
        sheetUndoManager?.redo()
    }

    /// Ensure the Undo/Redo menu items are validated against the sheet's manager.
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(undo(_:)):
            sheetUndoManager?.canUndo ?? false
        case #selector(redo(_:)):
            sheetUndoManager?.canRedo ?? false
        default:
            super.validateMenuItem(menuItem)
        }
    }

    override var intrinsicContentSize: NSSize {
        guard let container = textContainer,
              let manager = layoutManager
        else {
            return super.intrinsicContentSize
        }
        manager.ensureLayout(for: container)
        return CGSize(
            width: NSView.noIntrinsicMetric,
            height: manager.usedRect(for: container).height
        )
    }
}

// MARK: - Non-scrolling NSTextView so we can use a shared ScrollView

/// A SwiftUI bridge to a custom `NSTextView` that grows with its content.
///
/// `ExpandingTextEditor` wraps `GrowingTextView` so it can participate in a
/// shared `ScrollView` alongside the answer column. It reports per-line heights
/// back to SwiftUI to keep the two panes synchronized while scrolling.
///
/// The underlying `NSTextView` is the source of truth for text during editing;
/// `text` is updated reactively via `textDidChange` to avoid breaking undo/redo.
struct ExpandingTextEditor: NSViewRepresentable {
    @Binding var text: String
    let font: NSFont
    @Binding var lineHeights: [CGFloat]
    let syntaxHighlighter: SyntaxHighlighter
    let engine: CalculatorEngine
    let undoManager: UndoManager
    let isActive: Bool
    var onSetup: (GrowingTextView) -> Void
    @Environment(ThemeSettings.self) private var themeSettings

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> GrowingTextView {
        let textView = GrowingTextView()
        textView.sheetUndoManager = undoManager
        textView.isActive = isActive
        textView.autocompleteEngine = engine
        textView.isRichText = false
        textView.font = font
        textView.backgroundColor = .clear
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.allowsUndo = true
        textView.usesFindBar = true

        let smartSubs = themeSettings.smartSubstitutionsEnabled
        textView.isAutomaticQuoteSubstitutionEnabled = smartSubs
        textView.isAutomaticDashSubstitutionEnabled = smartSubs
        textView.isAutomaticLinkDetectionEnabled = smartSubs
        textView.isAutomaticTextReplacementEnabled = smartSubs
        // Note: isAutomaticPeriodSubstitutionEnabled is not available in AppKit
        // (it is UIKit-only). Period substitution is handled by the
        // `insertText` override in GrowingTextView when smartSubstitutionsEnabled
        // is false.
        textView.smartSubstitutionsEnabled = smartSubs
        textView.autocompleteEnabled = themeSettings.autocompleteEnabled
        textView.autocompleteMinimumPrefixLength = themeSettings.autocompleteMinimumPrefixLength

        textView.delegate = context.coordinator
        textView.layoutManager?.delegate = context.coordinator

        // Attach the syntax highlighter to the text storage
        textView.textStorage?.delegate = syntaxHighlighter
        syntaxHighlighter.textView = textView
        syntaxHighlighter.bind(to: themeSettings)

        // Seed the text view with the current bound text so it displays
        // correctly when the view is recreated (e.g., on sheet switch).
        textView.string = text

        context.coordinator.textView = textView
        DispatchQueue.main.async { onSetup(textView) }

        // Initial highlight after seeding text
        DispatchQueue.main.async {
            if let ts = textView.textStorage {
                syntaxHighlighter.forceFullHighlight(on: ts)
            }
        }

        return textView
    }

    func updateNSView(_ nsView: GrowingTextView, context: Context) {
        // Keep coordinator's parent reference in sync (defensive — standard pattern).
        context.coordinator.parent = self

        // Normal editor changes update the binding in textDidChange, so both values
        // already match here. A mismatch therefore represents an external model
        // replacement (document load, restore, or clear), which must be reflected
        // without adding an undo step. Ghost completions intentionally exist only
        // in NSTextStorage and must not trigger this synchronization.
        if !nsView.isUpdatingAutocompleteGhost, nsView.string != text {
            Self.setEditorText(
                nsView,
                text,
                registerUndo: false,
                syntaxHighlighter: syntaxHighlighter
            )
        }

        // Keep font in sync (guarded)
        if nsView.font != font {
            nsView.font = font
            nsView.invalidateIntrinsicContentSize()
            DispatchQueue.main.async {
                if let ts = nsView.textStorage {
                    syntaxHighlighter.forceFullHighlight(on: ts)
                }
            }
        }

        // Keep first-responder eligibility in sync with visibility
        if nsView.isActive, !isActive {
            nsView.discardAutocomplete()
        }
        nsView.isActive = isActive
        nsView.autocompleteEngine = engine

        // Keep smart substitution flags in sync with settings
        let smartSubs = themeSettings.smartSubstitutionsEnabled
        if nsView.smartSubstitutionsEnabled != smartSubs {
            nsView.isAutomaticQuoteSubstitutionEnabled = smartSubs
            nsView.isAutomaticDashSubstitutionEnabled = smartSubs
            nsView.isAutomaticLinkDetectionEnabled = smartSubs
            nsView.isAutomaticTextReplacementEnabled = smartSubs
            // Period substitution handled via insertText override (see makeNSView).
            nsView.smartSubstitutionsEnabled = smartSubs
        }

        if nsView.autocompleteEnabled, !themeSettings.autocompleteEnabled {
            nsView.discardAutocomplete()
        }
        nsView.autocompleteEnabled = themeSettings.autocompleteEnabled
        nsView.autocompleteMinimumPrefixLength = themeSettings.autocompleteMinimumPrefixLength
    }

    static func dismantleNSView(_ nsView: GrowingTextView, coordinator _: Coordinator) {
        // Per Apple docs: "Cleans up the presented AppKit view (and coordinator)
        // in anticipation of their removal." Remove all undo actions targeting
        // this text view so dangling targets don't remain in the undo manager
        // after the view is deallocated.
        nsView.sheetUndoManager?.removeAllActions(withTarget: nsView)
        nsView.closeAutocomplete()
        nsView.textStorage?.delegate = nil
        nsView.layoutManager?.delegate = nil
    }

    // MARK: Programmatic text setting (for future document load / clear)

    /// Replace the editor contents programmatically with correct undo behavior.
    ///
    /// - registerUndo: If false (document load), this clears the undo stack and does not create an undo step.
    ///                 If true (clear action), the replacement becomes undoable.
    static func setEditorText(_ textView: GrowingTextView, _ newText: String, registerUndo: Bool, syntaxHighlighter: SyntaxHighlighter) {
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)

        if registerUndo {
            guard textView.shouldChangeText(in: fullRange, replacementString: newText) else { return }
            textView.textStorage?.replaceCharacters(in: fullRange, with: newText)
            textView.didChangeText()
        } else {
            // Not undoable (load): clear the undo stack, then perform the
            // replacement with undo registration disabled so no undo step is
            // registered. removeAllActions() must run *before* disabling
            // registration — it interacts with the registration-disable counter
            // and would otherwise leave that counter at 0, causing the matching
            // enableUndoRegistration() below to throw an
            // NSInternalInconsistencyException. The disable/enable window must
            // actually wrap the text mutation (a defer scoped to the inner `if`
            // block fires at the end of that block, before the mutation).
            let um = textView.undoManager
            um?.removeAllActions()
            um?.disableUndoRegistration()
            textView.textStorage?.replaceCharacters(in: fullRange, with: newText)
            textView.didChangeText()
            um?.enableUndoRegistration()
        }

        // Re-highlight after programmatic change
        DispatchQueue.main.async {
            if let ts = textView.textStorage {
                syntaxHighlighter.forceFullHighlight(on: ts)
            }
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate, NSLayoutManagerDelegate {
        var parent: ExpandingTextEditor
        weak var textView: GrowingTextView?

        init(_ parent: ExpandingTextEditor) {
            self.parent = parent
        }

        private var lastEditWasAtomic = false
        private var lastEditWasDeletion = false

        func textView(_ textView: NSTextView,
                      shouldChangeTextIn affectedCharRange: NSRange,
                      replacementString: String?) -> Bool
        {
            let isInsert = (replacementString?.count == 1 && affectedCharRange.length == 0)
            let isDelete = (replacementString?.isEmpty == true && affectedCharRange.length > 0)
            lastEditWasAtomic = isInsert || isDelete
            lastEditWasDeletion = isDelete

            // Mark the active ghost as consumed when an incoming edit touches its
            // selected range. Subsequent `discardAutocomplete` (fired from
            // textViewDidChangeSelection, synchronously inside NSTextStorage's
            // endEditing pipeline) will then skip the deletion that previously
            // crashed the layout manager and corrupted user-typed content.
            if let gt = textView as? GrowingTextView,
               let ghostRange = gt.activeAutocompleteSelection,
               NSIntersectionRange(ghostRange, affectedCharRange).length > 0
            {
                gt.ghostEditConsumed = true
            }
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? GrowingTextView else { return }
            tv.invalidateIntrinsicContentSize()
            updateLineHeights(for: tv)

            // Ghost completions temporarily live in NSTextStorage for AppKit's
            // native completion behavior, but must not become sheet input.
            // Accepted completions are final edits and continue below normally.
            if tv.isUpdatingAutocompleteGhost {
                return
            }

            // Update SwiftUI mirror state
            parent.text = tv.string

            if lastEditWasAtomic {
                tv.breakUndoCoalescing()
            }

            if lastEditWasDeletion {
                tv.closeAutocomplete()
                return
            }

            showAutocompleteIfNeeded(for: tv)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? GrowingTextView else { return }
            tv.discardAutocompleteIfSelectionMoved()
        }

        private func showAutocompleteIfNeeded(for textView: GrowingTextView) {
            guard textView.autocompleteEnabled,
                  textView.selectedRange().length == 0,
                  let engine = textView.autocompleteEngine
            else {
                textView.closeAutocomplete()
                return
            }

            let cursorLocation = textView.selectedRange().location
            guard let range = textView.autocompleteProvider.completionRange(in: textView.string, cursorLocation: cursorLocation) else {
                textView.closeAutocomplete()
                return
            }
            let suggestions = textView.autocompleteProvider.suggestions(
                in: textView.string,
                cursorLocation: cursorLocation,
                engine: engine,
                minimumPrefixLength: textView.autocompleteMinimumPrefixLength
            )
            guard !suggestions.isEmpty else {
                textView.closeAutocomplete()
                return
            }

            textView.showAutocomplete(suggestions: suggestions, range: range)
        }

        func layoutManager(_: NSLayoutManager,
                           didCompleteLayoutFor _: NSTextContainer?,
                           atEnd layoutFinishedFlag: Bool)
        {
            guard layoutFinishedFlag, let tv = textView else { return }
            DispatchQueue.main.async { [weak self] in
                self?.updateLineHeights(for: tv)
            }
        }

        /// Measures the rendered height of every paragraph in the text view.
        ///
        /// Paragraphs correspond to logical lines (delimited by `\n`). The measured
        /// heights are published to `parent.lineHeights` so the answer column can
        /// align its rows with the editor. A fallback height is used for empty or
        /// trailing paragraphs to ensure the answer column never collapses.
        func updateLineHeights(for textView: GrowingTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            layoutManager.ensureLayout(for: textContainer)

            let fullString = textView.string as NSString
            let totalLength = fullString.length
            var heights: [CGFloat] = []
            var location = 0

            let fallbackHeight: CGFloat = {
                let a = NSAttributedString(string: " ",
                                           attributes: [.font: textView.font ?? NSFont.systemFont(ofSize: 14)])
                return ceil(a.size().height)
            }()

            repeat {
                let paraRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
                let glyphRange = layoutManager.glyphRange(
                    forCharacterRange: paraRange,
                    actualCharacterRange: nil
                )

                var paraHeight: CGFloat = 0
                layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
                    paraHeight += usedRect.height
                }

                heights.append(paraHeight > 0 ? paraHeight : fallbackHeight)
                location = NSMaxRange(paraRange)
            } while location < totalLength

            let endsWithNewline = totalLength > 0 && fullString.character(at: totalLength - 1) == unichar(("\n" as UnicodeScalar).value)
            if endsWithNewline {
                heights.append(fallbackHeight)
            }

            // Only publish when heights actually change to avoid a feedback loop:
            // writing to the @Binding triggers Sheet.objectWillChange, which
            // rebuilds CalculatorView, which calls updateNSView again.
            let tolerancesMatch = heights.count == parent.lineHeights.count &&
                zip(heights, parent.lineHeights).allSatisfy { abs($0 - $1) < 0.5 }
            if !tolerancesMatch {
                parent.lineHeights = heights
            }
        }
    }
}
