import Foundation

enum CalcError: Error, LocalizedError {
    case unexpectedToken(String)
    case unexpectedEndOfExpression
    case missingClosingParen
    case invalidNumber(String)
    case unknownCharacter(Character)
    case undefinedVariable(String)
    case undefinedFunction(String)
    case wrongArgCount(String)
    case missingReturn

    var errorDescription: String? {
        switch self {
        case .unexpectedToken(let t):    return "Unexpected token: '\(t)'"
        case .unexpectedEndOfExpression: return "Unexpected end of expression"
        case .missingClosingParen:       return "Missing closing parenthesis"
        case .invalidNumber(let n):      return "Invalid number: '\(n)'"
        case .unknownCharacter(let c):   return "Unknown character: '\(c)'"
        case .undefinedVariable(let v):  return "Undefined variable: '\(v)'"
        case .undefinedFunction(let f):  return "Undefined function: '\(f)'"
        case .wrongArgCount(let f):      return "Wrong argument count for function: '\(f)'"
        case .missingReturn:            return "Function did not return a value"
        }
    }
}
