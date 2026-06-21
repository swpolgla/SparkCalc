import Foundation

/// Errors thrown during tokenization, parsing, or evaluation.
///
/// All errors are currently swallowed by `evaluate(lines:)`, which returns an
/// empty string for invalid lines. These descriptions are useful for debugging
/// and may surface in a future error-reporting UI.
enum CalculatorError: Error, LocalizedError, Equatable {
    case unexpectedToken(String)
    case unexpectedEndOfExpression
    case missingClosingParen
    case invalidNumber(String)
    case unknownCharacter(Character)
    case undefinedVariable(String)
    case undefinedFunction(String)
    case wrongArgCount(String)
    case missingReturn
    case recursionLimitExceeded

    var errorDescription: String? {
        switch self {
        case let .unexpectedToken(t): "Unexpected token: '\(t)'"
        case .unexpectedEndOfExpression: "Unexpected end of expression"
        case .missingClosingParen: "Missing closing parenthesis"
        case let .invalidNumber(n): "Invalid number: '\(n)'"
        case let .unknownCharacter(c): "Unknown character: '\(c)'"
        case let .undefinedVariable(v): "Undefined variable: '\(v)'"
        case let .undefinedFunction(f): "Undefined function: '\(f)'"
        case let .wrongArgCount(f): "Wrong argument count for function: '\(f)'"
        case .missingReturn: "Function did not return a value"
        case .recursionLimitExceeded: "Recursion limit exceeded"
        }
    }
}
