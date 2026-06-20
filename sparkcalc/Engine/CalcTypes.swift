import Foundation

// MARK: - Token Types

/// The single-character operators recognized by the calculator.
///
/// Using an enum backed by `Character` instead of a raw `String` eliminates
/// heap allocations for operator tokens and makes invalid operators
/// unrepresentable at the type level.
enum Operator: Character, Equatable, Hashable, Sendable {
    case plus = "+"
    case minus = "-"
    case multiply = "*"
    case divide = "/"
    case power = "^"
    case percent = "%"
}

/// A lexical token produced by the calculator's tokenizer.
///
/// `Token` is the input vocabulary for the recursive-descent parser.
/// Each case represents an atomic unit of an expression: numbers, identifiers,
/// operators, and grouping punctuation.
enum Token: CustomStringConvertible, Equatable, Hashable, Sendable {
    case number(Double)
    case ident(String)
    case op(Operator)
    case lparen
    case rparen
    case comma

    var description: String {
        switch self {
        case .number(let v): return "\(v)"
        case .ident(let s): return s
        case .op(let op):   return String(op.rawValue)
        case .lparen:       return "("
        case .rparen:       return ")"
        case .comma:        return ","
        }
    }
}

/// A token paired with its source range.
///
/// `range` is relative to the string that was tokenized, not the full document.
/// This allows the syntax highlighter to map tokens back to exact character
/// positions when applying color attributes.
struct LocatedToken: Sendable {
    let token: Token
    let range: Range<String.Index>
}

// MARK: - Supporting Types

/// A user-defined function parsed from the sheet.
///
/// Functions are declared with a header line (`name(param1, param2) {`) followed
/// by a multi-line body and a closing `}`. The body is stored as raw strings and
/// evaluated line-by-line when the function is called.
struct FunctionDefinition {
    let name: String
    let parameters: [String]
    let body: [String]
}

/// Intermediate representation used during the function-collection pass.
///
/// `collectFunctions` walks the raw sheet and tags each line as either part of a
/// function definition or as an evaluable expression. This two-pass approach lets
/// the engine register all functions before any expressions are evaluated.
enum AnnotatedLine {
    case functionLine
    case evaluable(String)
}

/// Parsed components of a function declaration header.
///
/// Produced by `tryParseFunctionHeader` when a line matches the pattern
/// `name(param1, param2, ...) {`.
struct FunctionHeader {
    let name: String
    let parameters: [String]
}
