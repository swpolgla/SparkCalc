import Foundation

// MARK: - Tokenizer

/// Breaks expression strings into sequences of `LocatedToken`s.
///
/// Recognizes numbers (with optional scientific notation), identifiers, operators,
/// and grouping punctuation. Whitespace is skipped.
struct Tokenizer {

    func tokenize(_ expr: String) throws -> [LocatedToken] {
        var tokens: [LocatedToken] = []
        var i = expr.startIndex

        while i < expr.endIndex {
            let ch = expr[i]

            if ch.isWhitespace {
                i = expr.index(after: i)
                continue
            }

            let tokenStart = i

            if ch.isNumber || (ch == "." && expr.index(after: i) < expr.endIndex && expr[expr.index(after: i)].isNumber) {
                var numStr = ""
                while i < expr.endIndex && (expr[i].isNumber || expr[i] == ".") {
                    numStr.append(expr[i])
                    i = expr.index(after: i)
                }
                if i < expr.endIndex && (expr[i] == "e" || expr[i] == "E") {
                    numStr.append(expr[i])
                    i = expr.index(after: i)
                    if i < expr.endIndex && (expr[i] == "+" || expr[i] == "-") {
                        numStr.append(expr[i])
                        i = expr.index(after: i)
                    }
                    while i < expr.endIndex && expr[i].isNumber {
                        numStr.append(expr[i])
                        i = expr.index(after: i)
                    }
                }
                guard let value = Double(numStr) else { throw CalculatorError.invalidNumber(numStr) }
                tokens.append(LocatedToken(token: .number(value), range: tokenStart..<i))
                continue
            }

            if ch.isLetter || ch == "_" {
                var ident = ""
                while i < expr.endIndex && (expr[i].isLetter || expr[i].isNumber || expr[i] == "_" || expr[i] == ".") {
                    ident.append(expr[i])
                    i = expr.index(after: i)
                }
                tokens.append(LocatedToken(token: .ident(ident), range: tokenStart..<i))
                continue
            }

            switch ch {
            case "+", "-", "*", "/", "^", "%":
                tokens.append(LocatedToken(token: .op(String(ch)), range: tokenStart..<expr.index(after: i)))
            case "(":
                tokens.append(LocatedToken(token: .lparen, range: tokenStart..<expr.index(after: i)))
            case ")":
                tokens.append(LocatedToken(token: .rparen, range: tokenStart..<expr.index(after: i)))
            case ",":
                tokens.append(LocatedToken(token: .comma, range: tokenStart..<expr.index(after: i)))
            default:
                throw CalculatorError.unknownCharacter(ch)
            }
            i = expr.index(after: i)
        }
        return tokens
    }

    /// Checks whether `s` is a legal identifier.
    ///
    /// Identifiers must match `^[a-zA-Z_][a-zA-Z0-9_.]*$`.
    func isValidIdentifier(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        return s.range(of: #"^[a-zA-Z_][a-zA-Z0-9_.]*$"#, options: .regularExpression) != nil
    }
}
