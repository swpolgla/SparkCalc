import Foundation

// MARK: - Token Types

enum Token: CustomStringConvertible {
    case number(Double)
    case ident(String)
    case op(String)
    case lparen
    case rparen
    case comma

    var description: String {
        switch self {
        case .number(let v): return "\(v)"
        case .ident(let s): return s
        case .op(let s):    return s
        case .lparen:       return "("
        case .rparen:       return ")"
        case .comma:        return ","
        }
    }
}

struct LocatedToken {
    let token: Token
    let range: Range<String.Index>
}

// MARK: - Supporting Types

struct FunctionDefinition {
    let name: String
    let parameters: [String]
    let body: [String]
}

enum AnnotatedLine {
    case functionLine
    case evaluable(String)
}

struct FunctionHeader {
    let name: String
    let parameters: [String]
}
