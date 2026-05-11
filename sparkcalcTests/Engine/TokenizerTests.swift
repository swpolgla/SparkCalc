import Testing
@testable import sparkcalc

struct TokenizerTests {

    // MARK: - Basic Tokenization

    @Test func tokenizeNumberAndIdentifier() throws {
        let t = Tokenizer()
        let tokens = try t.tokenize("42 + abc")
        #expect(tokens.count == 3)
        if case .number(let v) = tokens[0].token { #expect(v == 42) }
        if case .op(let op) = tokens[1].token { #expect(op == "+") }
        if case .ident(let s) = tokens[2].token { #expect(s == "abc") }
    }

    @Test func tokenizeOperatorsAndPunctuation() throws {
        let t = Tokenizer()
        let tokens = try t.tokenize("(1, 2)")
        #expect(tokens.count == 5)
        if case .lparen = tokens[0].token {} else { Issue.record("Expected lparen") }
        if case .number(let v) = tokens[1].token { #expect(v == 1) }
        if case .comma = tokens[2].token {} else { Issue.record("Expected comma") }
        if case .number(let v) = tokens[3].token { #expect(v == 2) }
        if case .rparen = tokens[4].token {} else { Issue.record("Expected rparen") }
    }

    // MARK: - Scientific Notation

    @Test func tokenizeScientificNotation() throws {
        let t = Tokenizer()
        let cases: [(String, Double)] = [
            ("1e10", 1e10),
            ("1.5E-3", 1.5e-3),
            ("2e+5", 2e5),
        ]
        for (input, expected) in cases {
            let tokens = try t.tokenize(input)
            #expect(tokens.count == 1)
            if case .number(let v) = tokens[0].token {
                #expect(v == expected)
            }
        }
    }

    @Test func tokenizeDecimalStartingWithDot() throws {
        let t = Tokenizer()
        let tokens = try t.tokenize(".5 + .25")
        #expect(tokens.count == 3)
        if case .number(let v) = tokens[0].token { #expect(v == 0.5) }
        if case .number(let v) = tokens[2].token { #expect(v == 0.25) }
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

    @Test func validIdentifierChecks() {
        let t = Tokenizer()
        #expect(t.isValidIdentifier("abc") == true)
        #expect(t.isValidIdentifier("_abc") == true)
        #expect(t.isValidIdentifier("abc123") == true)
        #expect(t.isValidIdentifier("123abc") == false)
        #expect(t.isValidIdentifier("") == false)
        #expect(t.isValidIdentifier("π") == false) // Unicode fails regex
    }

    // MARK: - Token Descriptions

    @Test func tokenDescriptions() {
        #expect(Token.number(5.0).description == "5.0")
        #expect(Token.ident("x").description == "x")
        #expect(Token.op("+").description == "+")
        #expect(Token.lparen.description == "(")
        #expect(Token.rparen.description == ")")
        #expect(Token.comma.description == ",")
    }
}
