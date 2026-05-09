import SwiftUI
import AppKit

// MARK: - Growing NSTextView subclass

/// An `NSTextView` subclass that reports its height based on laid-out text.
///
/// By overriding `intrinsicContentSize`, the view pushes its container height
/// in SwiftUI rather than scrolling internally. This allows the text view to live
/// inside a shared `ScrollView` while still growing vertically with content.
class GrowingTextView: NSTextView {
    override var intrinsicContentSize: NSSize {
        guard let container = textContainer,
              let manager = layoutManager else {
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
    var onSetup: (GrowingTextView) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> GrowingTextView {
        let textView = GrowingTextView()
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

        textView.delegate = context.coordinator
        textView.layoutManager?.delegate = context.coordinator

        // Attach the syntax highlighter to the text storage
        textView.textStorage?.delegate = syntaxHighlighter
        syntaxHighlighter.textView = textView

        context.coordinator.textView = textView
        DispatchQueue.main.async { onSetup(textView) }

        // Initial highlight (empty doc is harmless)
        DispatchQueue.main.async {
            if let ts = textView.textStorage {
                syntaxHighlighter.forceFullHighlight(on: ts)
            }
        }

        return textView
    }

    func updateNSView(_ nsView: GrowingTextView, context: Context) {
        // IMPORTANT: Do not continuously push `text` into the NSTextView.
        // Doing so breaks native undo/redo. The NSTextView is the source of truth
        // during normal editing. We will update SwiftUI state from textDidChange.

        // Keep font in sync (guarded)
        if nsView.font != font {
            nsView.font = font
            DispatchQueue.main.async {
                if let ts = nsView.textStorage {
                    self.syntaxHighlighter.forceFullHighlight(on: ts)
                }
            }
        }

        nsView.invalidateIntrinsicContentSize()
        DispatchQueue.main.async {
            context.coordinator.updateLineHeights(for: nsView)
        }
    }

    // MARK: Programmatic text setting (for future document load / clear)

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

        init(_ parent: ExpandingTextEditor) { self.parent = parent }

        private var lastEditWasAtomic = false

        func textView(_ textView: NSTextView,
                      shouldChangeTextIn affectedCharRange: NSRange,
                      replacementString: String?) -> Bool {
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

        func layoutManager(_ layoutManager: NSLayoutManager,
                           didCompleteLayoutFor textContainer: NSTextContainer?,
                           atEnd layoutFinishedFlag: Bool) {
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

            if totalLength == 0 || fullString.character(at: totalLength - 1) == unichar(("\n" as UnicodeScalar).value) {
                heights.append(fallbackHeight)
            }

            parent.lineHeights = heights
        }
    }
}
