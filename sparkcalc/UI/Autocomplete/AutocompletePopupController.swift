import AppKit

@MainActor
final class AutocompletePopupController {
    private final class PopupPanel: NSPanel {
        override var canBecomeKey: Bool {
            false
        }

        override var canBecomeMain: Bool {
            false
        }
    }

    private final class ListView: NSView {
        var suggestions: [AutocompleteSuggestion] = [] {
            didSet { needsDisplay = true }
        }

        var selectedIndex: Int = 0 {
            didSet { needsDisplay = true }
        }

        var onClick: ((Int) -> Void)?

        private let rowHeight: CGFloat = 28
        private let horizontalPadding: CGFloat = 10

        override var isFlipped: Bool {
            true
        }

        override var allowsVibrancy: Bool {
            true
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)

            for (index, suggestion) in suggestions.enumerated() {
                let rowRect = NSRect(x: 4, y: CGFloat(index) * rowHeight + 4, width: bounds.width - 8, height: rowHeight)
                if index == selectedIndex {
                    NSColor.selectedContentBackgroundColor.withAlphaComponent(0.9).setFill()
                    NSBezierPath(roundedRect: rowRect, xRadius: 6, yRadius: 6).fill()
                }

                draw(suggestion: suggestion, in: rowRect, selected: index == selectedIndex)
            }
        }

        override func mouseDown(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            let index = Int((point.y - 4) / rowHeight)
            guard suggestions.indices.contains(index) else { return }
            selectedIndex = index
            onClick?(index)
        }

        private func draw(suggestion: AutocompleteSuggestion, in rowRect: NSRect, selected: Bool) {
            let nameColor: NSColor = selected ? .selectedMenuItemTextColor : .labelColor
            let detailColor: NSColor = selected ? .selectedMenuItemTextColor.withAlphaComponent(0.75) : .secondaryLabelColor

            let nameAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: nameColor
            ]
            let detailAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: detailColor
            ]

            let name = NSAttributedString(string: suggestion.displayText, attributes: nameAttributes)
            let detail = NSAttributedString(string: suggestion.detailText ?? "", attributes: detailAttributes)
            let detailSize = detail.size()
            let nameRect = NSRect(
                x: rowRect.minX + horizontalPadding,
                y: rowRect.midY - name.size().height / 2,
                width: max(0, rowRect.width - detailSize.width - horizontalPadding * 3),
                height: name.size().height
            )
            let detailRect = NSRect(
                x: rowRect.maxX - horizontalPadding - detailSize.width,
                y: rowRect.midY - detailSize.height / 2,
                width: detailSize.width,
                height: detailSize.height
            )

            name.draw(in: nameRect)
            detail.draw(in: detailRect)
        }
    }

    private let panel: PopupPanel
    private let listView: ListView
    private var suggestions: [AutocompleteSuggestion] = []

    var selectedSuggestion: AutocompleteSuggestion? {
        guard suggestions.indices.contains(listView.selectedIndex) else { return nil }
        return suggestions[listView.selectedIndex]
    }

    var isShown: Bool {
        panel.isVisible
    }

    init(onCommit: @escaping (AutocompleteSuggestion) -> Void) {
        listView = ListView(frame: .zero)
        panel = PopupPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        let effectView = NSVisualEffectView()
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 10
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = true
        effectView.addSubview(listView)

        panel.contentView = effectView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .transient, .ignoresCycle]

        listView.onClick = { [weak self] index in
            guard let self, suggestions.indices.contains(index) else { return }
            onCommit(suggestions[index])
        }
    }

    func show(suggestions: [AutocompleteSuggestion], relativeTo textView: NSTextView) {
        guard !suggestions.isEmpty, let window = textView.window else {
            close()
            return
        }

        self.suggestions = suggestions
        listView.suggestions = suggestions
        listView.selectedIndex = 0

        let width: CGFloat = 340
        let visibleRows = min(suggestions.count, 8)
        let height = CGFloat(visibleRows) * 28 + 8
        let frame = NSRect(origin: popupOrigin(width: width, height: height, textView: textView), size: CGSize(width: width, height: height))

        panel.setFrame(frame, display: true)
        listView.frame = NSRect(origin: .zero, size: frame.size)

        if !panel.isVisible {
            window.addChildWindow(panel, ordered: .above)
        }
    }

    func close() {
        guard panel.isVisible else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        suggestions = []
        listView.suggestions = []
    }

    @discardableResult
    func moveSelection(_ delta: Int) -> AutocompleteSuggestion? {
        guard !suggestions.isEmpty else { return nil }
        let next = max(0, min(suggestions.count - 1, listView.selectedIndex + delta))
        listView.selectedIndex = next
        return selectedSuggestion
    }

    private func popupOrigin(width: CGFloat, height: CGFloat, textView: NSTextView) -> CGPoint {
        let caretRange = NSRange(location: textView.selectedRange().location, length: 0)
        var actualRange = NSRange(location: 0, length: 0)
        let caretRect = textView.firstRect(forCharacterRange: caretRange, actualRange: &actualRange)
        let screen = textView.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var x = caretRect.minX
        var y = caretRect.minY - height - 4

        if x + width > screen.maxX {
            x = screen.maxX - width - 8
        }
        if y < screen.minY {
            y = caretRect.maxY + 4
        }

        return CGPoint(x: max(screen.minX + 8, x), y: y)
    }
}
