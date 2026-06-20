import Testing
@testable import sparkcalc

struct TokenizerTests {

    // MARK: - Basic Tokenization

    @Test func tokenizeNumberAndIdentifier() throws {
        let t = Tokenizer()
        let tokens = try t.tokenize("42 + abc")
        #expect(tokens.count == 3)
        guard case .number(let v) = tokens[0].token else {
            Issue.record("Expected .number, got \(tokens[0].token)")
            return
        }
        #expect(v == 42)
        guard case .op(let op) = tokens[1].token else {
            Issue.record("Expected .op, got \(tokens[1].token)")
            return
        }
        #expect(op == .plus)
        guard case .ident(let s) = tokens[2].token else {
            Issue.record("Expected .ident, got \(tokens[2].token)")
            return
        }
        #expect(s == "abc")
    }

    @Test func tokenizeOperatorsAndPunctuation() throws {
        let t = Tokenizer()
        let tokens = try t.tokenize("(1, 2)")
        #expect(tokens.count == 5)
        guard case .lparen = tokens[0].token else { Issue.record("Expected lparen"); return }
        guard case .number(let v) = tokens[1].token else { Issue.record("Expected number"); return }
        #expect(v == 1)
        guard case .comma = tokens[2].token else { Issue.record("Expected comma"); return }
        guard case .number(let v) = tokens[3].token else { Issue.record("Expected number"); return }
        #expect(v == 2)
        guard case .rparen = tokens[4].token else { Issue.record("Expected rparen"); return }
    }

    // MARK: - Scientific Notation

    @Test(arguments: zip(["1e10", "1.5E-3", "2e+5"], [1e10, 1.5e-3, 2e5]))
    func tokenizeScientificNotation(_ input: String, expected: Double) throws {
        let t = Tokenizer()
        let tokens = try t.tokenize(input)
        #expect(tokens.count == 1)
        guard case .number(let v) = tokens[0].token else {
            Issue.record("Expected .number, got \(tokens[0].token)")
            return
        }
        #expect(v == expected)
    }

    @Test func tokenizeDecimalStartingWithDot() throws {
        let t = Tokenizer()
        let tokens = try t.tokenize(".5 + .25")
        #expect(tokens.count == 3)
        guard case .number(let v) = tokens[0].token else { Issue.record("Expected number"); return }
        #expect(v == 0.5)
        guard case .number(let v) = tokens[2].token else { Issue.record("Expected number"); return }
        #expect(v == 0.25)
    }

    // MARK: - Dotted Identifiers

    @Test func tokenizeDottedIdentifier() throws {
        let t = Tokenizer()
        let tokens = try t.tokenize("my.var + 5")
        #expect(tokens.count == 3)
        guard case .ident(let s) = tokens[0].token else { Issue.record("Expected ident"); return }
        #expect(s == "my.var")
        guard case .number(let v) = tokens[2].token else { Issue.record("Expected number"); return }
        #expect(v == 5)
    }

    @Test func tokenizeDottedIdentifierWithConsecutiveDots() throws {
        let t = Tokenizer()
        let tokens = try t.tokenize("my...var")
        #expect(tokens.count == 1)
        guard case .ident(let s) = tokens[0].token else { Issue.record("Expected ident"); return }
        #expect(s == "my...var")
    }

    // MARK: - Range Correctness

    @Test func tokenizeRangesAreCorrect() throws {
        let t = Tokenizer()
        let expr = "42 + abc"
        let tokens = try t.tokenize(expr)
        #expect(tokens.count == 3)

        // "42" covers indices 0..<2
        #expect(tokens[0].range == expr.startIndex..<expr.index(expr.startIndex, offsetBy: 2))
        // "+" covers index 3 (after the space)
        let plusIdx = expr.index(expr.startIndex, offsetBy: 3)
        #expect(tokens[1].range == plusIdx..<expr.index(after: plusIdx))
        // "abc" covers indices 5..<8
        let abcStart = expr.index(expr.startIndex, offsetBy: 5)
        let abcEnd = expr.index(expr.startIndex, offsetBy: 8)
        #expect(tokens[2].range == abcStart..<abcEnd)
    }

    @Test func tokenizeEmptyStringReturnsEmpty() throws {
        let t = Tokenizer()
        let tokens = try t.tokenize("")
        #expect(tokens.isEmpty)
    }

    @Test func tokenizeWhitespaceOnlyReturnsEmpty() throws {
        let t = Tokenizer()
        let tokens = try t.tokenize("   ")
        #expect(tokens.isEmpty)
    }

    // MARK: - Error Cases

    @Test func tokenizeInvalidNumberThrows() {
        let t = Tokenizer()
        #expect(throws: CalculatorError.invalidNumber("1e")) {
            try t.tokenize("1e")
        }
        #expect(throws: CalculatorError.invalidNumber("1e+")) {
            try t.tokenize("1e+")
        }
    }

    @Test func tokenizeUnknownCharacterThrows() {
        let t = Tokenizer()
        #expect(throws: CalculatorError.unknownCharacter("$")) {
            try t.tokenize("5 $ 3")
        }
        #expect(throws: CalculatorError.unknownCharacter("=")) {
            try t.tokenize("a = 1")
        }
    }

    // MARK: - Identifier Validation

    @Test(arguments: zip(
        ["abc", "_abc", "abc123", "123abc", "", "my.var", "my...var", "a.b.c", ".my", "my."],
        [true,   true,    true,     false,    false, true,     true,        true,    false, true]
    ))
    func identifierValidation(_ input: String, expected: Bool) {
        let t = Tokenizer()
        #expect(t.isValidIdentifier(input) == expected)
    }

    @Test func unicodeIdentifierFailsRegex() {
        let t = Tokenizer()
        #expect(t.isValidIdentifier("π") == false)
    }

    // MARK: - Token Descriptions

    @Test(arguments: zip(
        [Token.number(5.0), Token.ident("x"), Token.op(.plus), Token.lparen, Token.rparen, Token.comma],
        ["5.0",              "x",              "+",            "(",          ")",          ","]
    ))
    func tokenDescription(_ token: Token, expected: String) {
        #expect(token.description == expected)
    }
}
