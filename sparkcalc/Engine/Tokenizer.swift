import Foundation

// MARK: - Tokenizer

/// Breaks expression strings into sequences of `LocatedToken`s.
///
/// Recognizes numbers (with optional scientific notation), identifiers, operators,
/// and grouping punctuation. Whitespace is skipped.
struct Tokenizer {

    /// Precompiled regex for validating identifiers (`^[a-zA-Z_][a-zA-Z0-9_.]*$`).
    /// Cached to avoid recompiling on every `isValidIdentifier` call, which
    /// is invoked per-line during highlighting and assignment detection.
    private static let identifierRegex: NSRegularExpression = {
        let pattern = #"^[a-zA-Z_][a-zA-Z0-9_.]*$"#
        return try! NSRegularExpression(pattern: pattern)
    }()

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

            if ch.isNumber || (ch == "." && {
                let nextIdx = expr.index(after: i)
                return nextIdx < expr.endIndex && expr[nextIdx].isNumber
            }()) {
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
            case "+": tokens.append(LocatedToken(token: .op(.plus), range: tokenStart..<expr.index(after: i)))
            case "-": tokens.append(LocatedToken(token: .op(.minus), range: tokenStart..<expr.index(after: i)))
            case "*": tokens.append(LocatedToken(token: .op(.multiply), range: tokenStart..<expr.index(after: i)))
            case "/": tokens.append(LocatedToken(token: .op(.divide), range: tokenStart..<expr.index(after: i)))
            case "^": tokens.append(LocatedToken(token: .op(.power), range: tokenStart..<expr.index(after: i)))
            case "%": tokens.append(LocatedToken(token: .op(.percent), range: tokenStart..<expr.index(after: i)))
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
        let length = (s as NSString).length
        return Self.identifierRegex.firstMatch(in: s, range: NSRange(location: 0, length: length)) != nil
    }
}
