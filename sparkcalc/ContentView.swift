import SwiftUI
import AppKit

// MARK: - Syntax Theme

/// Central location for all highlight colors. Tweak any of these to change
/// the appearance of syntax highlighting throughout the app.
struct SyntaxTheme {
    var number: NSColor              = .textColor           // numeric literals
    var variableDeclaration: NSColor = .systemBlue          // left side of "=" in top-level assignments
    var variableUse: NSColor         = .systemCyan          // subsequent uses of variables & built-in constants
    var localParamDeclaration: NSColor = .systemTeal        // parameter names in function header
    var localParamUse: NSColor       = .systemMint          // parameter uses inside function body
    var localVarDeclaration: NSColor = .systemTeal          // left side of "=" inside function body
    var localVarUse: NSColor         = .systemMint          // subsequent uses of local vars inside function body
    var functionDecl: NSColor        = .systemPurple.shadow(withLevel: 0.2)!        // function name in declaration header
    var functionCall: NSColor        = .systemPurple        // valid function calls
    var invalidCall: NSColor         = .systemRed           // unknown function calls
    var operatorColor: NSColor       = .secondaryLabelColor // +, -, *, /, ^, %, =
    var plainText: NSColor           = .textColor           // everything else
}

// MARK: - Highlight State (for incremental optimization)

enum LineKind: Equatable {
    case functionHeader(String)   // associated value is function name
    case functionBody(String)     // associated value is owning function name
    case functionClose
    case evaluable
}

struct HighlightState {
    let lines: [String]
    let knownVariablesAfterLine: [Set<String>]
    let lineClassifications: [LineKind]
    let functionNames: Set<String>
}

// MARK: - Syntax Highlighter

class SyntaxHighlighter: NSObject, NSTextStorageDelegate {

    var theme = SyntaxTheme()
    var engine: CalculatorEngine

    /// Set by ExpandingTextEditor during makeNSView so we can:
    /// - disable undo registration while applying highlight attributes
    /// - optionally access view-specific context later
    weak var textView: NSTextView?

    private var previousState: HighlightState?
    private var isHighlighting = false

    init(engine: CalculatorEngine) {
        self.engine = engine
        super.init()
    }

    /// Forces a complete re-highlight, discarding any incremental state.
    /// Call this after external changes that may strip text attributes
    /// (e.g., font assignment, programmatic text replacement).
    func forceFullHighlight(on textStorage: NSTextStorage) {
        previousState = nil
        performHighlighting(on: textStorage)
    }

    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        // Only respond to edits that changed characters, not just attributes.
        guard editedMask.contains(.editedCharacters) else { return }
        // Prevent re-entrant highlighting.
        guard !isHighlighting else { return }

        // Defer highlighting to avoid modifying textStorage during this callback.
        DispatchQueue.main.async { [weak self] in
            self?.performHighlighting(on: textStorage)
        }
    }

    // MARK: - Main Highlighting Entry Point

    private func performHighlighting(on textStorage: NSTextStorage) {
        guard !isHighlighting else { return }
        isHighlighting = true
        defer { isHighlighting = false }

        let fullString = textStorage.string
        let lines = fullString.components(separatedBy: "\n")

        // Build current classification and state using a fresh engine pass.
        let classificationEngine = CalculatorEngine()

        let _ = classificationEngine.collectFunctions(from: lines)

        // Build line classifications
        let lineClassifications = buildLineClassifications(lines: lines, engine: classificationEngine)

        // Evaluate to populate variables
        _ = classificationEngine.evaluate(lines: lines)

        // Build known variables progression
        var knownVariables: Set<String> = classificationEngine.builtInConstants
        var knownVariablesAfterLine: [Set<String>] = []

        // Check if we can do an incremental update
        let currentFunctionNames = Set(classificationEngine.functions.keys)
        var canIncremental = false
        var dirtyStart = 0

        if let prev = previousState,
           prev.lines.count == lines.count,
           prev.functionNames == currentFunctionNames {
            // Find the first line that changed
            var firstDirty: Int? = nil
            for i in 0..<lines.count {
                if lines[i] != prev.lines[i] || lineClassifications[i] != prev.lineClassifications[i] {
                    firstDirty = i
                    break
                }
            }

            if let dirty = firstDirty {
                dirtyStart = dirty
                canIncremental = true
                // Seed knownVariables up to the dirty line from previous state
                if dirty > 0 {
                    knownVariables = prev.knownVariablesAfterLine[dirty - 1]
                }
            } else {
                // No lines changed — nothing to do.
                previousState = HighlightState(
                    lines: lines,
                    knownVariablesAfterLine: prev.knownVariablesAfterLine,
                    lineClassifications: lineClassifications,
                    functionNames: currentFunctionNames
                )
                return
            }
        }

        let startLine = canIncremental ? dirtyStart : 0

        // If incremental, fill knownVariablesAfterLine for lines before startLine
        if canIncremental, let prev = previousState {
            for i in 0..<startLine {
                knownVariablesAfterLine.append(prev.knownVariablesAfterLine[i])
            }
        }

        // Ensure highlight attribute updates do not pollute undo stack.
        let undoManager = textView?.undoManager
        undoManager?.disableUndoRegistration()
        defer { undoManager?.enableUndoRegistration() }

        textStorage.beginEditing()

        // Process each line from startLine onward
        var charOffset = 0
        for i in 0..<lines.count {
            let line = lines[i]
            let lineLength = (line as NSString).length
            let newlineLength = (i < lines.count - 1) ? 1 : 0 // account for \n
            let lineNSRange = NSRange(location: charOffset, length: lineLength)

            if i < startLine {
                // Skip lines before the dirty range (incremental)
                charOffset += lineLength + newlineLength
                continue
            }

            // Reset this line to plain text color
            if lineLength > 0 {
                textStorage.addAttribute(.foregroundColor, value: theme.plainText, range: lineNSRange)
            }

            // Apply highlighting based on classification
            let classification = lineClassifications[i]
            highlightLine(
                line: line,
                classification: classification,
                charOffset: charOffset,
                knownVariables: &knownVariables,
                classificationEngine: classificationEngine,
                textStorage: textStorage
            )

            knownVariablesAfterLine.append(knownVariables)

            // Check for stability point (incremental optimization)
            if canIncremental, let prev = previousState, i >= dirtyStart, i < prev.knownVariablesAfterLine.count {
                if knownVariables == prev.knownVariablesAfterLine[i]
                    && lines[i] == prev.lines[i]
                    && lineClassifications[i] == prev.lineClassifications[i] {
                    // Stability reached — copy remaining state from previous
                    textStorage.endEditing()

                    for j in (i + 1)..<lines.count {
                        knownVariablesAfterLine.append(prev.knownVariablesAfterLine[j])
                    }

                    previousState = HighlightState(
                        lines: lines,
                        knownVariablesAfterLine: knownVariablesAfterLine,
                        lineClassifications: lineClassifications,
                        functionNames: currentFunctionNames
                    )
                    return
                }
            }

            charOffset += lineLength + newlineLength
        }

        textStorage.endEditing()

        previousState = HighlightState(
            lines: lines,
            knownVariablesAfterLine: knownVariablesAfterLine,
            lineClassifications: lineClassifications,
            functionNames: currentFunctionNames
        )
    }

    // MARK: - Line Classification Builder

    private func buildLineClassifications(lines: [String], engine: CalculatorEngine) -> [LineKind] {
        var classifications: [LineKind] = []
        var i = 0

        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)

            if let header = engine.tryParseFunctionHeader(trimmed) {
                classifications.append(.functionHeader(header.name))
                i += 1

                while i < lines.count {
                    let bodyLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if bodyLine == "}" {
                        classifications.append(.functionClose)
                        i += 1
                        break
                    }
                    classifications.append(.functionBody(header.name))
                    i += 1
                }
            } else {
                classifications.append(.evaluable)
                i += 1
            }
        }

        return classifications
    }

    // MARK: - Per-Line Highlighting

    private func highlightLine(
        line: String,
        classification: LineKind,
        charOffset: Int,
        knownVariables: inout Set<String>,
        classificationEngine: CalculatorEngine,
        textStorage: NSTextStorage
    ) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        switch classification {
        case .functionHeader(let funcName):
            highlightFunctionHeader(
                line: line,
                funcName: funcName,
                charOffset: charOffset,
                classificationEngine: classificationEngine,
                textStorage: textStorage
            )

        case .functionBody(let funcName):
            highlightFunctionBody(
                line: line,
                funcName: funcName,
                charOffset: charOffset,
                knownVariables: knownVariables,
                classificationEngine: classificationEngine,
                textStorage: textStorage
            )

        case .functionClose:
            // Closing brace remains plainText — nothing to do.
            break

        case .evaluable:
            highlightEvaluableLine(
                line: line,
                charOffset: charOffset,
                knownVariables: &knownVariables,
                classificationEngine: classificationEngine,
                textStorage: textStorage
            )
        }
    }

    // MARK: - Evaluable Line Highlighting

    private func highlightEvaluableLine(
        line: String,
        charOffset: Int,
        knownVariables: inout Set<String>,
        classificationEngine: CalculatorEngine,
        textStorage: NSTextStorage
    ) {
        // Assignment split is required because tokenizer does not recognize '='.
        if let assignIdx = classificationEngine.findTopLevelAssignment(in: line) {
            let leftSide = String(line[line.startIndex..<assignIdx])
            let rightSide = String(line[line.index(after: assignIdx)...])
            let leftOffset = charOffset
            let equalsOffset = charOffset + line.distance(from: line.startIndex, to: assignIdx)
            let rightOffset = equalsOffset + 1

            // Color '='
            textStorage.addAttribute(.foregroundColor, value: theme.operatorColor, range: NSRange(location: equalsOffset, length: 1))

            // Left side: declaration
            let varName = leftSide.trimmingCharacters(in: .whitespaces)
            if classificationEngine.isValidIdentifier(varName) {
                knownVariables.insert(varName)
                if let leftTokens = try? classificationEngine.tokenize(leftSide) {
                    for locatedToken in leftTokens {
                        let tokenNSRange = nsRange(from: locatedToken.range, in: leftSide, charOffset: leftOffset)
                        if case .ident = locatedToken.token {
                            textStorage.addAttribute(.foregroundColor, value: theme.variableDeclaration, range: tokenNSRange)
                        } else if case .op = locatedToken.token {
                            textStorage.addAttribute(.foregroundColor, value: theme.operatorColor, range: tokenNSRange)
                        }
                    }
                }
            }

            // Right side: expression tokens
            if let rightTokens = try? classificationEngine.tokenize(rightSide) {
                colorTokens(
                    rightTokens,
                    in: rightSide,
                    charOffset: rightOffset,
                    localScope: nil,
                    knownVariables: knownVariables,
                    classificationEngine: classificationEngine,
                    textStorage: textStorage
                )
            }
        } else {
            // No '=' present
            if let tokens = try? classificationEngine.tokenize(line) {
                colorTokens(
                    tokens,
                    in: line,
                    charOffset: charOffset,
                    localScope: nil,
                    knownVariables: knownVariables,
                    classificationEngine: classificationEngine,
                    textStorage: textStorage
                )
            }
        }
    }

    // MARK: - Function Header Highlighting

    private func highlightFunctionHeader(
        line: String,
        funcName: String,
        charOffset: Int,
        classificationEngine: CalculatorEngine,
        textStorage: NSTextStorage
    ) {
        // Tokenize only up to '{'
        let beforeBrace = String(line.prefix(while: { $0 != "{" }))
        guard let tokens = try? classificationEngine.tokenize(beforeBrace) else { return }

        let funcDef = classificationEngine.functions[funcName]
        let paramNames = Set(funcDef?.parameters ?? [])

        for locatedToken in tokens {
            let tokenNSRange = nsRange(from: locatedToken.range, in: beforeBrace, charOffset: charOffset)
            switch locatedToken.token {
            case .ident(let name):
                if name == funcName {
                    textStorage.addAttribute(.foregroundColor, value: theme.functionDecl, range: tokenNSRange)
                } else if paramNames.contains(name) {
                    textStorage.addAttribute(.foregroundColor, value: theme.localParamDeclaration, range: tokenNSRange)
                }
            case .op:
                textStorage.addAttribute(.foregroundColor, value: theme.operatorColor, range: tokenNSRange)
            default:
                break
            }
        }
    }

    // MARK: - Function Body Highlighting

    private func highlightFunctionBody(
        line: String,
        funcName: String,
        charOffset: Int,
        knownVariables: Set<String>,
        classificationEngine: CalculatorEngine,
        textStorage: NSTextStorage
    ) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Build local scope
        let funcDef = classificationEngine.functions[funcName]
        let paramNames = Set(funcDef?.parameters ?? [])
        var localVars = Set<String>()

        // Collect prior local var declarations (best-effort, given only body strings)
        if let funcDef = funcDef {
            for bodyLine in funcDef.body {
                let bodyTrimmed = bodyLine.trimmingCharacters(in: .whitespaces)
                if bodyTrimmed == trimmed { break }
                if let assignIdx = classificationEngine.findTopLevelAssignment(in: bodyTrimmed) {
                    let varName = String(bodyTrimmed[bodyTrimmed.startIndex..<assignIdx]).trimmingCharacters(in: .whitespaces)
                    if classificationEngine.isValidIdentifier(varName) && !paramNames.contains(varName) {
                        localVars.insert(varName)
                    }
                }
            }
        }

        // Strip "return" for tokenization (no hinting; return stays plainText)
        var processString = line
        var processOffset = charOffset
        if trimmed.hasPrefix("return"), let returnRange = line.range(of: "return") {
            processString = String(line[returnRange.upperBound...])
            processOffset = charOffset + line.distance(from: line.startIndex, to: returnRange.upperBound)
        }

        // Assignment split for body lines too
        if let assignIdx = classificationEngine.findTopLevelAssignment(in: processString) {
            let leftSide = String(processString[processString.startIndex..<assignIdx])
            let rightSide = String(processString[processString.index(after: assignIdx)...])
            let leftOffset = processOffset
            let equalsOffset = processOffset + processString.distance(from: processString.startIndex, to: assignIdx)
            let rightOffset = equalsOffset + 1

            textStorage.addAttribute(.foregroundColor, value: theme.operatorColor, range: NSRange(location: equalsOffset, length: 1))

            let varName = leftSide.trimmingCharacters(in: .whitespaces)
            if classificationEngine.isValidIdentifier(varName) {
                localVars.insert(varName)

                if let leftTokens = try? classificationEngine.tokenize(leftSide) {
                    for locatedToken in leftTokens {
                        let tokenNSRange = nsRange(from: locatedToken.range, in: leftSide, charOffset: leftOffset)
                        if case .ident(let name) = locatedToken.token {
                            if paramNames.contains(name) {
                                textStorage.addAttribute(.foregroundColor, value: theme.localParamUse, range: tokenNSRange)
                            } else {
                                textStorage.addAttribute(.foregroundColor, value: theme.localVarDeclaration, range: tokenNSRange)
                            }
                        } else if case .op = locatedToken.token {
                            textStorage.addAttribute(.foregroundColor, value: theme.operatorColor, range: tokenNSRange)
                        }
                    }
                }
            }

            let localScope = LocalScope(paramNames: paramNames, localVarNames: localVars)
            if let rightTokens = try? classificationEngine.tokenize(rightSide) {
                colorTokens(
                    rightTokens,
                    in: rightSide,
                    charOffset: rightOffset,
                    localScope: localScope,
                    knownVariables: knownVariables,
                    classificationEngine: classificationEngine,
                    textStorage: textStorage
                )
            }
        } else {
            let localScope = LocalScope(paramNames: paramNames, localVarNames: localVars)
            if let tokens = try? classificationEngine.tokenize(processString) {
                colorTokens(
                    tokens,
                    in: processString,
                    charOffset: processOffset,
                    localScope: localScope,
                    knownVariables: knownVariables,
                    classificationEngine: classificationEngine,
                    textStorage: textStorage
                )
            }
        }
    }

    // MARK: - Shared Token Coloring

    private func colorTokens(
        _ tokens: [LocatedToken],
        in sourceString: String,
        charOffset: Int,
        localScope: LocalScope?,
        knownVariables: Set<String>,
        classificationEngine: CalculatorEngine,
        textStorage: NSTextStorage
    ) {
        for (idx, locatedToken) in tokens.enumerated() {
            let tokenNSRange = nsRange(from: locatedToken.range, in: sourceString, charOffset: charOffset)
            let color = colorForToken(
                locatedToken: locatedToken,
                index: idx,
                allTokens: tokens,
                localScope: localScope,
                knownVariables: knownVariables,
                classificationEngine: classificationEngine
            )
            textStorage.addAttribute(.foregroundColor, value: color, range: tokenNSRange)
        }
    }

    // MARK: - Token Coloring Logic

    private struct LocalScope {
        let paramNames: Set<String>
        let localVarNames: Set<String>
    }

    private func colorForToken(
        locatedToken: LocatedToken,
        index: Int,
        allTokens: [LocatedToken],
        localScope: LocalScope?,
        knownVariables: Set<String>,
        classificationEngine: CalculatorEngine
    ) -> NSColor {
        switch locatedToken.token {
        case .number:
            // You asked that numbers remain default
            return theme.plainText

        case .ident(let name):
            // Function call?
            let nextIndex = index + 1
            if nextIndex < allTokens.count, case .lparen = allTokens[nextIndex].token {
                let isKnown = CalculatorEngine.builtInFunctions.contains(name)
                    || classificationEngine.functions[name] != nil
                return isKnown ? theme.functionCall : theme.invalidCall
            }

            if name == "return" {
                return theme.plainText
            }

            if let scope = localScope {
                if scope.paramNames.contains(name) { return theme.localParamUse }
                if scope.localVarNames.contains(name) { return theme.localVarUse }
            }

            if knownVariables.contains(name) {
                return theme.variableUse
            }

            return theme.plainText

        case .op:
            return theme.operatorColor

        case .lparen, .rparen, .comma:
            return theme.plainText
        }
    }

    // MARK: - Range Helpers

    private func nsRange(from range: Range<String.Index>, in string: String, charOffset: Int) -> NSRange {
        let start = string.distance(from: string.startIndex, to: range.lowerBound)
        let length = string.distance(from: range.lowerBound, to: range.upperBound)
        return NSRange(location: charOffset + start, length: length)
    }
}

// MARK: - Growing NSTextView subclass
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

        // Initial highlight (empty doc -> harmless)
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

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? GrowingTextView else { return }
            // Update SwiftUI mirror state
            parent.text = tv.string
            tv.invalidateIntrinsicContentSize()
            updateLineHeights(for: tv)
        }

        func layoutManager(_ layoutManager: NSLayoutManager,
                           didCompleteLayoutFor textContainer: NSTextContainer?,
                           atEnd layoutFinishedFlag: Bool) {
            guard layoutFinishedFlag, let tv = textView else { return }
            DispatchQueue.main.async { [weak self] in
                self?.updateLineHeights(for: tv)
            }
        }

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
