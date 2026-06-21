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

        // IMPORTANT: Do not continuously push `text` into the NSTextView.
        // Doing so breaks native undo/redo. The NSTextView is the source of truth
        // during normal editing. We will update SwiftUI state from textDidChange.

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
        nsView.isActive = isActive

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
    }

    static func dismantleNSView(_ nsView: GrowingTextView, coordinator _: Coordinator) {
        // Per Apple docs: "Cleans up the presented AppKit view (and coordinator)
        // in anticipation of their removal." Remove all undo actions targeting
        // this text view so dangling targets don't remain in the undo manager
        // after the view is deallocated.
        nsView.sheetUndoManager?.removeAllActions(withTarget: nsView)
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
            // Not undoable (load): disable undo registration and clear undo stack
            if let um = textView.undoManager {
                um.disableUndoRegistration()
                defer { um.enableUndoRegistration() }
                um.removeAllActions()
            }
            textView.textStorage?.replaceCharacters(in: fullRange, with: newText)
            textView.didChangeText()
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

        func textView(_: NSTextView,
                      shouldChangeTextIn affectedCharRange: NSRange,
                      replacementString: String?) -> Bool
        {
            let isInsert = (replacementString?.count == 1 && affectedCharRange.length == 0)
            let isDelete = (replacementString?.isEmpty == true && affectedCharRange.length == 1)
            lastEditWasAtomic = isInsert || isDelete
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? GrowingTextView else { return }
            // Update SwiftUI mirror state
            parent.text = tv.string
            tv.invalidateIntrinsicContentSize()
            updateLineHeights(for: tv)

            if lastEditWasAtomic {
                tv.breakUndoCoalescing()
            }
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
