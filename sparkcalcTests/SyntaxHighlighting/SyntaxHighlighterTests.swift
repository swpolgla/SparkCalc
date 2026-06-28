import AppKit
@testable import sparkcalc
import Testing

struct SyntaxHighlighterTests {
    // MARK: - Helpers

    private struct HighlighterContext {
        let highlighter: SyntaxHighlighter
        let textStorage: NSTextStorage
        let textView: NSTextView
    }

    /// Creates a fully-wired highlighter + text view + text storage for testing.
    private func makeHighlighter(text: String) -> HighlighterContext {
        let engine = CalculatorEngine()
        let highlighter = SyntaxHighlighter(engine: engine)
        let textStorage = NSTextStorage(string: text)
        let textView = makeTextView(textStorage: textStorage)
        highlighter.textView = textView
        textStorage.delegate = highlighter
        highlighter.forceFullHighlight(on: textStorage)
        return HighlighterContext(highlighter: highlighter, textStorage: textStorage, textView: textView)
    }

    /// Creates an NSTextView wired to the given text storage.
    private func makeTextView(textStorage: NSTextStorage) -> NSTextView {
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer()
        layoutManager.addTextContainer(textContainer)
        return NSTextView(frame: .zero, textContainer: textContainer)
    }

    /// Returns the foreground color at the given UTF-16 location, or nil if none.
    private func foregroundColor(at location: Int, in textStorage: NSTextStorage) -> NSColor? {
        textStorage.attribute(.foregroundColor, at: location, effectiveRange: nil) as? NSColor
    }

    // MARK: - UTF-16 Range Correctness (locks in C1 fix)

    @Test func emojiLineUsesUTF16OffsetsForEqualsSign() {
        // "😀 = 5" — 😀 is 2 UTF-16 code units (surrogate pair), so:
        // 😀 at UTF-16 0-1, space at 2, = at 3, space at 4, 5 at 5
        // If String.distance (grapheme count) were used, = would be at location 2 (wrong).
        let ctx = makeHighlighter(text: "😀 = 5")

        // The = sign must be at UTF-16 location 3, not grapheme location 2.
        let equalsColor = foregroundColor(at: 3, in: ctx.textStorage)
        #expect(equalsColor?.isEqual(to: ctx.highlighter.theme.operatorColor) == true)

        // Location 2 is the space before = — should NOT have operator color.
        let spaceColor = foregroundColor(at: 2, in: ctx.textStorage)
        #expect(spaceColor?.isEqual(to: ctx.highlighter.theme.operatorColor) != true)
    }

    @Test func emojiLineUsesUTF16OffsetsForNumber() {
        // "😀 = 5" — the 5 is at UTF-16 location 5.
        let ctx = makeHighlighter(text: "😀 = 5")

        let numberColor = foregroundColor(at: 5, in: ctx.textStorage)
        #expect(numberColor?.isEqual(to: ctx.highlighter.theme.number) == true)
    }

    @Test func cjkLineUsesUTF16OffsetsForEqualsSign() {
        // "你 = 3" — 你 is a single UTF-16 code unit (BMP), so UTF-16 and
        // grapheme offsets happen to match. This test ensures CJK doesn't break.
        // Using a supplementary-plane character would be ideal, but 你 still
        // verifies the code path works for non-ASCII.
        let ctx = makeHighlighter(text: "你 = 3")

        // 你 at 0, space at 1, = at 2, space at 3, 3 at 4
        let equalsColor = foregroundColor(at: 2, in: ctx.textStorage)
        #expect(equalsColor?.isEqual(to: ctx.highlighter.theme.operatorColor) == true)
    }

    // MARK: - Color Precedence (via NSTextStorage attributes)

    @Test func variableDeclarationGetsDeclarationColor() {
        // "a = 5" — 'a' should get variableDeclaration, '=' gets operatorColor, '5' gets number
        let ctx = makeHighlighter(text: "a = 5")

        let aVarColor = foregroundColor(at: 0, in: ctx.textStorage)
        #expect(aVarColor?.isEqual(to: ctx.highlighter.theme.variableDeclaration) == true)

        let equalsColor = foregroundColor(at: 2, in: ctx.textStorage)
        #expect(equalsColor?.isEqual(to: ctx.highlighter.theme.operatorColor) == true)

        let fiveColor = foregroundColor(at: 4, in: ctx.textStorage)
        #expect(fiveColor?.isEqual(to: ctx.highlighter.theme.number) == true)
    }

    @Test func knownVariableUseGetsVariableUseColor() {
        // "a = 5\na + 1" — second 'a' should get variableUse, not variableDeclaration
        let ctx = makeHighlighter(text: "a = 5\na + 1")

        // Line 2: "a + 1" starts at UTF-16 offset 6 (a=0, space=1, ==2, space=3, 5=4, \n=5, a=6)
        let aVarColor = foregroundColor(at: 0, in: ctx.textStorage)
        #expect(aVarColor?.isEqual(to: ctx.highlighter.theme.variableDeclaration) == true)

        let aUseColor = foregroundColor(at: 6, in: ctx.textStorage)
        #expect(aUseColor?.isEqual(to: ctx.highlighter.theme.variableUse) == true)
    }

    @Test func failedAssignmentDoesNotMakeVariableKnown() {
        let text = "x = missing\nx + 1"
        let ctx = makeHighlighter(text: text)
        let secondX = (text as NSString).range(of: "x", options: .backwards).location
        let xUseColor = foregroundColor(at: secondX, in: ctx.textStorage)
        #expect(xUseColor?.isEqual(to: ctx.highlighter.theme.variableUse) != true)
        #expect(xUseColor?.isEqual(to: ctx.highlighter.theme.plainText) == true)
    }

    @Test func functionCallGetsFunctionCallColor() {
        // "sqrt(16)" — 'sqrt' should get functionCall, '16' gets number
        let ctx = makeHighlighter(text: "sqrt(16)")

        // s=0, q=1, r=2, t=3, (=4, 1=5, 6=6, )=7
        let sqrtColor = foregroundColor(at: 0, in: ctx.textStorage)
        #expect(sqrtColor?.isEqual(to: ctx.highlighter.theme.functionCall) == true)

        let oneColor = foregroundColor(at: 5, in: ctx.textStorage)
        #expect(oneColor?.isEqual(to: ctx.highlighter.theme.number) == true)
    }

    @Test func builtInConstantGetsVariableUseColor() {
        // "pi" — built-in constant should get variableUse color
        let ctx = makeHighlighter(text: "pi")

        let piColor = foregroundColor(at: 0, in: ctx.textStorage)
        #expect(piColor?.isEqual(to: ctx.highlighter.theme.variableUse) == true)
    }

    // MARK: - Function Body Highlighting

    @Test func functionHeaderNameGetsDeclarationColor() {
        let ctx = makeHighlighter(text: "f(a, b) {\n  return a + b\n}\nf(1, 2)")

        // Line 1: "f(a, b) {" — 'f' at location 0 gets functionDecl
        let fDeclColor = foregroundColor(at: 0, in: ctx.textStorage)
        #expect(fDeclColor?.isEqual(to: ctx.highlighter.theme.functionDecl) == true)
    }

    @Test func functionParameterInHeaderGetsParamDeclarationColor() {
        let ctx = makeHighlighter(text: "f(a, b) {\n  return a + b\n}\nf(1, 2)")

        // Line 1: "f(a, b) {" — 'a' at location 2 gets localParamDeclaration
        let aParamColor = foregroundColor(at: 2, in: ctx.textStorage)
        #expect(aParamColor?.isEqual(to: ctx.highlighter.theme.localParamDeclaration) == true)
    }

    @Test func functionParameterInBodyGetsParamUseColor() {
        let ctx = makeHighlighter(text: "f(a, b) {\n  return a + b\n}\nf(1, 2)")

        // Line 2: "  return a + b"
        // Line 1 "f(a, b) {" = 9 chars + \n = 10, so line 2 starts at offset 10
        // "  return " = 9 chars, "a" is at offset 10 + 9 = 19
        let aUseColor = foregroundColor(at: 19, in: ctx.textStorage)
        #expect(aUseColor?.isEqual(to: ctx.highlighter.theme.localParamUse) == true)
    }

    @Test func functionCallInBodyGetsFunctionCallColor() {
        let ctx = makeHighlighter(text: "f(x) {\n  return sqrt(x)\n}\nf(16)")

        // Line 2: "  return sqrt(x)"
        // Line 1 "f(x) {" = 6 chars + \n = 7, so line 2 starts at offset 7
        // "  return " = 9 chars, "sqrt" starts at offset 7 + 9 = 16
        let sqrtColor = foregroundColor(at: 16, in: ctx.textStorage)
        #expect(sqrtColor?.isEqual(to: ctx.highlighter.theme.functionCall) == true)
    }

    // MARK: - forceFullHighlight

    @Test func forceFullHighlightClearsIncrementalState() {
        let engine = CalculatorEngine()
        let highlighter = SyntaxHighlighter(engine: engine)
        let textStorage = NSTextStorage(string: "a = 1")
        let textView = makeTextView(textStorage: textStorage)
        highlighter.textView = textView
        textStorage.delegate = highlighter

        // First highlight
        highlighter.forceFullHighlight(on: textStorage)
        let aColorBefore = foregroundColor(at: 0, in: textStorage)
        #expect(aColorBefore?.isEqual(to: highlighter.theme.variableDeclaration) == true)

        // Change text and force full highlight again
        textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: "b = 2")
        highlighter.forceFullHighlight(on: textStorage)

        // 'b' at location 0 should now get variableDeclaration
        let bColor = foregroundColor(at: 0, in: textStorage)
        #expect(bColor?.isEqual(to: highlighter.theme.variableDeclaration) == true)
    }

    // MARK: - Operator Coloring

    @Test func operatorsGetOperatorColor() {
        let ctx = makeHighlighter(text: "1 + 2")

        // 1=0, space=1, +=2, space=3, 2=4
        let plusColor = foregroundColor(at: 2, in: ctx.textStorage)
        #expect(plusColor?.isEqual(to: ctx.highlighter.theme.operatorColor) == true)

        let oneColor = foregroundColor(at: 0, in: ctx.textStorage)
        #expect(oneColor?.isEqual(to: ctx.highlighter.theme.number) == true)

        let twoColor = foregroundColor(at: 4, in: ctx.textStorage)
        #expect(twoColor?.isEqual(to: ctx.highlighter.theme.number) == true)
    }

    // MARK: - Engine Sharing Invariant

    @Test func highlighterUsesSharedEngine() {
        let engine = CalculatorEngine()
        let highlighter = SyntaxHighlighter(engine: engine)
        #expect(highlighter.engine === engine)
    }

    @Test func highlighterDoesNotCreateFreshEngine() {
        // Verify the engine is the same instance that gets evaluate(lines:) called on it.
        // We check this by populating variables through the highlighter's engine
        // and confirming they're visible.
        let engine = CalculatorEngine()
        let highlighter = SyntaxHighlighter(engine: engine)
        let textStorage = NSTextStorage(string: "a = 5\na")
        let textView = makeTextView(textStorage: textStorage)
        highlighter.textView = textView
        textStorage.delegate = highlighter
        highlighter.forceFullHighlight(on: textStorage)

        // After highlighting, the engine should have 'a' in its variables
        #expect(engine.variables["a"] == 5.0)
    }
}
