import AppKit
import Observation

/// Real-time syntax highlighter for the calculator input pane.
///
/// `SyntaxHighlighter` observes the `NSTextStorage` of the input editor and
/// re-colors text after every edit. It uses an incremental optimization: by
/// comparing the current document state against a cached `HighlightState`, it
/// limits re-highlighting to the suffix of lines that may have changed.
///
/// Coloring rules are driven by a pass over the sheet's shared
/// `CalculatorEngine` — the same instance used to compute the answer column.
/// This guarantees highlighting and answers always agree on variable and
/// function state. Do NOT create a fresh engine for highlighting; see the
/// shared-engine invariant documented in AGENTS.md.
@MainActor
final class SyntaxHighlighter: NSObject, NSTextStorageDelegate {

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

    /// Binds the highlighter to a shared `ThemeSettings` so it re-highlights
    /// whenever the user changes a syntax color.
    func bind(to settings: ThemeSettings) {
        // Apply the current theme immediately so a non-default theme is in
        // effect from the first highlight pass (not just on future changes).
        self.theme = settings.theme
        if let textStorage = textView?.textStorage {
            forceFullHighlight(on: textStorage)
        }
        observeTheme(in: settings)
    }

    private func observeTheme(in settings: ThemeSettings) {
        withObservationTracking {
            _ = settings.theme
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.theme = settings.theme
                guard let textView = self.textView,
                      let textStorage = textView.textStorage else { return }
                self.forceFullHighlight(on: textStorage)
                // Re-register observation (withObservationTracking is one-shot)
                self.observeTheme(in: settings)
            }
        }
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

    /// Re-colors the entire text storage, using incremental logic where possible.
    ///
    /// This method runs a two-pass analysis:
    /// 1. **Classification pass** — `collectFunctions` identifies function blocks.
    /// 2. **Evaluation pass** — `evaluate` populates global variables line-by-line.
    ///
    /// It then compares the resulting state with `previousState`. If line count and
    /// function names are unchanged, it finds the first dirty line and reuses the
    /// cached variable set up to that point. Re-highlighting stops early if the
    /// variable state stabilizes (no new assignments) before the end of the document.
    private func performHighlighting(on textStorage: NSTextStorage) {
        guard !isHighlighting else { return }
        isHighlighting = true
        defer { isHighlighting = false }

        let fullString = textStorage.string
        let lines = fullString.components(separatedBy: "\n")

        // Evaluate the shared engine to populate functions and variables.
        self.engine.evaluate(lines: lines)

        // Build line classifications
        let lineClassifications = buildLineClassifications(lines: lines, engine: self.engine)

        // Build known variables progression
        var knownVariables: Set<String> = CalculatorEngine.builtInConstants
        var knownVariablesAfterLine: [Set<String>] = []

        // Check if we can do an incremental update
        let currentFunctionNames = Set(self.engine.functions.keys)
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
                classificationEngine: self.engine,
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

    /// Walks the sheet line-by-line and tags each as a function header, body, close,
    /// or evaluable expression.
    ///
    /// Function blocks are identified by matching a header with `tryParseFunctionHeader`,
    /// then consuming subsequent lines until a closing `}` is found.
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
            let equalsOffset = charOffset + assignIdx.utf16Offset(in: line)
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

    /// Highlights a single line inside a function body, respecting local scope.
    ///
    /// Local scope is built by scanning prior lines in the same function body for
    /// assignments. This is a best-effort approach: it only sees lines that appear
    /// earlier in the body array and does not account for conditional or loop scopes
    /// (the language does not currently support control flow).
    private func highlightFunctionBody(
        line: String,
        funcName: String,
        charOffset: Int,
        knownVariables: Set<String>,
        classificationEngine: CalculatorEngine,
        textStorage: NSTextStorage
    ) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Resolve function definition and extract parameter names.
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
            processOffset = charOffset + returnRange.upperBound.utf16Offset(in: line)
        }

        // Assignment split for body lines too
        if let assignIdx = classificationEngine.findTopLevelAssignment(in: processString) {
            let leftSide = String(processString[processString.startIndex..<assignIdx])
            let rightSide = String(processString[processString.index(after: assignIdx)...])
            let leftOffset = processOffset
            let equalsOffset = processOffset + assignIdx.utf16Offset(in: processString)
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

    /// Scope container for local variables inside a function body.
    ///
    /// Used to resolve identifier colors with the following precedence:
    /// 1. Function parameters (`paramNames`)
    /// 2. Local variables declared earlier in the body (`localVarNames`)
    /// 3. Global variables known at this point in the sheet
    /// 4. Built-in constants
    /// 5. Plain text (unknown identifier)
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
            return theme.number

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

    /// Converts a `Range<String.Index>` to an `NSRange` relative to the full document.
    ///
    /// Uses `.utf16Offset(in:)` (not `String.distance`) because `NSTextStorage`
    /// requires UTF-16 code unit offsets for compatibility with emoji and CJK
    /// characters that span surrogate pairs. See AGENTS.md "Common Pitfalls".
    private func nsRange(from range: Range<String.Index>, in string: String, charOffset: Int) -> NSRange {
        let start = range.lowerBound.utf16Offset(in: string)
        let end = range.upperBound.utf16Offset(in: string)
        return NSRange(location: charOffset + start, length: end - start)
    }
}
