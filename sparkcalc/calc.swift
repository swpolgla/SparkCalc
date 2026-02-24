//
//  calc.swift
//  sparkcalc
//
//  Created by Steven Polglase on 2/17/26.
//

import Foundation

// MARK: - Public Entry Point

/// Evaluates an array of expression lines and returns a result for each.
/// Every input line — including function definition lines and blank lines — has
/// a corresponding entry in the output. Function definition lines and blank/
/// invalid lines return "".
public func EvaluateLines(_ lines: [String]) -> [String] {
    let engine = CalculatorEngine()
    return engine.evaluate(lines: lines)
}

// MARK: - Number Formatting

private func formatResult(_ value: Double) -> String {
    if value.isNaN      { return "NaN" }
    if value.isInfinite { return value > 0 ? "∞" : "-∞" }

    if value == value.rounded() && abs(value) < 1e15 {
        return String(format: "%.0f", value)
    }

    var str = String(format: "%.15g", value)
    if str.contains(".") && !str.contains("e") && !str.contains("E") {
        str = str.replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }
    return str
}

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

// MARK: - Engine

class CalculatorEngine {

    static let builtInFunctions: Set<String> = [
        "sqrt", "cbrt", "abs", "ceil", "floor", "round",
        "sin", "cos", "tan", "asin", "acos", "atan", "atan2",
        "log", "log2", "log10", "exp", "pow",
        "min", "max", "hypot"
    ]

    let builtInConstants: Set<String> = [
        "pi", "π", "e", "phi", "φ",
        "sqrt2", "sqrt3", "ln2", "ln10", "log2e", "log10e",
        "tau", "τ", "inf", "infinity", "nan",
        "c", "g", "G", "h", "k", "Na", "R"
    ]

    var variables: [String: Double] = [
        "pi":      Double.pi,
        "π":       Double.pi,
        "e":       M_E,
        "phi":     1.6180339887498948482,
        "φ":       1.6180339887498948482,
        "sqrt2":   2.0.squareRoot(),
        "sqrt3":   3.0.squareRoot(),
        "ln2":     log(2.0),
        "ln10":    log(10.0),
        "log2e":   log2(M_E),
        "log10e":  log10(M_E),
        "tau":     2.0 * Double.pi,
        "τ":       2.0 * Double.pi,
        "inf":     Double.infinity,
        "infinity": Double.infinity,
        "nan":     Double.nan,
        "c":       299_792_458.0,
        "g":       9.80665,
        "G":       6.67430e-11,
        "h":       6.62607015e-34,
        "k":       1.380649e-23,
        "Na":      6.02214076e23,
        "R":       8.314462618,
    ]

    var functions: [String: FunctionDefinition] = [:]

    func evaluate(lines: [String]) -> [String] {
        let annotated = collectFunctions(from: lines)
        var results: [String] = []

        for entry in annotated {
            switch entry {
            case .functionLine:
                results.append("")

            case .evaluable(let raw):
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else {
                    results.append("")
                    continue
                }
                do {
                    let value = try evaluateLine(trimmed)
                    results.append(formatResult(value))
                } catch {
                    results.append("")
                }
            }
        }
        return results
    }

    // MARK: - Function Collection

    enum AnnotatedLine {
        case functionLine
        case evaluable(String)
    }

    func collectFunctions(from lines: [String]) -> [AnnotatedLine] {
        var annotated: [AnnotatedLine] = []
        var i = 0

        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)

            if let funcDef = tryParseFunctionHeader(trimmed) {
                annotated.append(.functionLine)
                i += 1

                var bodyLines: [String] = []

                while i < lines.count {
                    let bodyLine = lines[i].trimmingCharacters(in: .whitespaces)
                    annotated.append(.functionLine)
                    i += 1
                    if bodyLine == "}" {
                        break
                    }
                    bodyLines.append(bodyLine)
                }

                functions[funcDef.name] = FunctionDefinition(
                    name: funcDef.name,
                    parameters: funcDef.parameters,
                    body: bodyLines
                )
            } else {
                annotated.append(.evaluable(lines[i]))
                i += 1
            }
        }

        return annotated
    }

    struct FunctionHeader {
        let name: String
        let parameters: [String]
    }

    func tryParseFunctionHeader(_ line: String) -> FunctionHeader? {
        let pattern = #"^([a-zA-Z_][a-zA-Z0-9_]*)\(([^)]*)\)\s*\{$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let nameRange = Range(match.range(at: 1), in: line),
              let paramsRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        let name = String(line[nameRange])
        let rawParams = String(line[paramsRange])
        let params = rawParams.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return FunctionHeader(name: name, parameters: params)
    }

    // MARK: - Line Evaluation

    private func evaluateLine(_ line: String) throws -> Double {
        if let assignRange = findTopLevelAssignment(in: line) {
            let varName = String(line[line.startIndex..<assignRange]).trimmingCharacters(in: .whitespaces)
            if isValidIdentifier(varName) {
                let exprStr = String(line[line.index(after: assignRange)...]).trimmingCharacters(in: .whitespaces)
                let value = try evaluateExpression(exprStr, localVars: [:])
                variables[varName] = value
                return value
            }
        }
        return try evaluateExpression(line, localVars: [:])
    }

    func findTopLevelAssignment(in line: String) -> String.Index? {
        var depth = 0
        var prev: Character = "\0"
        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]
            if ch == "(" { depth += 1 }
            else if ch == ")" { depth -= 1 }
            else if ch == "=" && depth == 0 {
                let nextIdx = line.index(after: i)
                let next: Character = nextIdx < line.endIndex ? line[nextIdx] : "\0"
                if prev != "!" && prev != "<" && prev != ">" && prev != "=" && next != "=" {
                    return i
                }
            }
            prev = ch
            i = line.index(after: i)
        }
        return nil
    }

    func isValidIdentifier(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        return s.range(of: #"^[a-zA-Z_][a-zA-Z0-9_]*$"#, options: .regularExpression) != nil
    }

    // MARK: - Expression Evaluation (Recursive Descent Parser)

    func evaluateExpression(_ expr: String, localVars: [String: Double]) throws -> Double {
        let locatedTokens = try tokenize(expr)
        let tokens = locatedTokens.map { $0.token }
        var pos = 0
        let result = try parseAddSub(tokens: tokens, pos: &pos, localVars: localVars)
        if pos != tokens.count {
            throw CalcError.unexpectedToken(tokens[pos].description)
        }
        return result
    }

    private func parseAddSub(tokens: [Token], pos: inout Int, localVars: [String: Double]) throws -> Double {
        var left = try parseMulDiv(tokens: tokens, pos: &pos, localVars: localVars)
        while pos < tokens.count {
            if case .op(let op) = tokens[pos], op == "+" || op == "-" {
                pos += 1
                let right = try parseMulDiv(tokens: tokens, pos: &pos, localVars: localVars)
                left = op == "+" ? left + right : left - right
            } else { break }
        }
        return left
    }

    private func parseMulDiv(tokens: [Token], pos: inout Int, localVars: [String: Double]) throws -> Double {
        var left = try parseUnary(tokens: tokens, pos: &pos, localVars: localVars)
        while pos < tokens.count {
            if case .op(let op) = tokens[pos], op == "*" || op == "/" || op == "%" {
                pos += 1
                let right = try parseUnary(tokens: tokens, pos: &pos, localVars: localVars)
                switch op {
                case "*": left = left * right
                case "/": left = left / right
                case "%": left = left.truncatingRemainder(dividingBy: right)
                default: break
                }
            } else { break }
        }
        return left
    }

    private func parseUnary(tokens: [Token], pos: inout Int, localVars: [String: Double]) throws -> Double {
        if pos < tokens.count, case .op(let op) = tokens[pos], op == "-" || op == "+" {
            pos += 1
            let val = try parsePower(tokens: tokens, pos: &pos, localVars: localVars)
            return op == "-" ? -val : val
        }
        return try parsePower(tokens: tokens, pos: &pos, localVars: localVars)
    }

    private func parsePower(tokens: [Token], pos: inout Int, localVars: [String: Double]) throws -> Double {
        let base = try parsePostfix(tokens: tokens, pos: &pos, localVars: localVars)
        if pos < tokens.count, case .op(let op) = tokens[pos], op == "^" {
            pos += 1
            let exp = try parseUnary(tokens: tokens, pos: &pos, localVars: localVars)
            return pow(base, exp)
        }
        return base
    }

    private func parsePostfix(tokens: [Token], pos: inout Int, localVars: [String: Double]) throws -> Double {
        var val = try parsePrimary(tokens: tokens, pos: &pos, localVars: localVars)
        while pos < tokens.count, case .op(let op) = tokens[pos], op == "%" {
            let nextPos = pos + 1
            // If the next token starts a new operand, this % is binary modulo —
            // leave it for parseMulDiv to handle.
            if nextPos < tokens.count {
                switch tokens[nextPos] {
                case .number, .ident, .lparen:
                    return val
                default:
                    break // operator, rparen, comma, or end → postfix percentage
                }
            }
            val = val / 100.0
            pos += 1
        }
        return val
    }

    private func parsePrimary(tokens: [Token], pos: inout Int, localVars: [String: Double]) throws -> Double {
        guard pos < tokens.count else { throw CalcError.unexpectedEndOfExpression }

        switch tokens[pos] {
        case .number(let v):
            pos += 1
            return v

        case .ident(let name):
            pos += 1
            if pos < tokens.count, case .lparen = tokens[pos] {
                pos += 1
                var args: [Double] = []
                if pos < tokens.count, case .rparen = tokens[pos] {
                    // empty arg list
                } else {
                    args.append(try parseAddSub(tokens: tokens, pos: &pos, localVars: localVars))
                    while pos < tokens.count, case .comma = tokens[pos] {
                        pos += 1
                        args.append(try parseAddSub(tokens: tokens, pos: &pos, localVars: localVars))
                    }
                }
                guard pos < tokens.count, case .rparen = tokens[pos] else {
                    throw CalcError.missingClosingParen
                }
                pos += 1
                return try callFunction(name: name, args: args)
            }
            if let val = localVars[name] { return val }
            if let val = variables[name]  { return val }
            throw CalcError.undefinedVariable(name)

        case .lparen:
            pos += 1
            let val = try parseAddSub(tokens: tokens, pos: &pos, localVars: localVars)
            guard pos < tokens.count, case .rparen = tokens[pos] else {
                throw CalcError.missingClosingParen
            }
            pos += 1
            return val

        case .rparen:
            throw CalcError.unexpectedToken(")")

        default:
            throw CalcError.unexpectedToken(tokens[pos].description)
        }
    }

    // MARK: - Function Invocation

    private func callFunction(name: String, args: [Double]) throws -> Double {
        switch name {
        case "sqrt":  guard args.count == 1 else { throw CalcError.wrongArgCount(name) }; return sqrt(args[0])
        case "cbrt":  guard args.count == 1 else { throw CalcError.wrongArgCount(name) }; return cbrt(args[0])
        case "abs":   guard args.count == 1 else { throw CalcError.wrongArgCount(name) }; return abs(args[0])
        case "ceil":  guard args.count == 1 else { throw CalcError.wrongArgCount(name) }; return ceil(args[0])
        case "floor": guard args.count == 1 else { throw CalcError.wrongArgCount(name) }; return floor(args[0])
        case "round": guard args.count == 1 else { throw CalcError.wrongArgCount(name) }; return round(args[0])
        case "sin":   guard args.count == 1 else { throw CalcError.wrongArgCount(name) }; return sin(args[0])
        case "cos":   guard args.count == 1 else { throw CalcError.wrongArgCount(name) }; return cos(args[0])
        case "tan":   guard args.count == 1 else { throw CalcError.wrongArgCount(name) }; return tan(args[0])
        case "asin":  guard args.count == 1 else { throw CalcError.wrongArgCount(name) }; return asin(args[0])
        case "acos":  guard args.count == 1 else { throw CalcError.wrongArgCount(name) }; return acos(args[0])
        case "atan":  guard args.count == 1 else { throw CalcError.wrongArgCount(name) }; return atan(args[0])
        case "atan2": guard args.count == 2 else { throw CalcError.wrongArgCount(name) }; return atan2(args[0], args[1])
        case "log":   guard args.count == 1 else { throw CalcError.wrongArgCount(name) }; return log(args[0])
        case "log2":  guard args.count == 1 else { throw CalcError.wrongArgCount(name) }; return log2(args[0])
        case "log10": guard args.count == 1 else { throw CalcError.wrongArgCount(name) }; return log10(args[0])
        case "exp":   guard args.count == 1 else { throw CalcError.wrongArgCount(name) }; return exp(args[0])
        case "pow":   guard args.count == 2 else { throw CalcError.wrongArgCount(name) }; return pow(args[0], args[1])
        case "min":   guard args.count >= 2 else { throw CalcError.wrongArgCount(name) }; return args.min()!
        case "max":   guard args.count >= 2 else { throw CalcError.wrongArgCount(name) }; return args.max()!
        case "hypot": guard args.count == 2 else { throw CalcError.wrongArgCount(name) }; return hypot(args[0], args[1])
        default: break
        }

        guard let def = functions[name] else { throw CalcError.undefinedFunction(name) }
        guard args.count == def.parameters.count else { throw CalcError.wrongArgCount(name) }

        var localVars: [String: Double] = [:]
        for (param, value) in zip(def.parameters, args) {
            localVars[param] = value
        }
        return try executeFunctionBody(def.body, localVars: &localVars)
    }

    private func executeFunctionBody(_ body: [String], localVars: inout [String: Double]) throws -> Double {
        for line in body {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("return") {
                let rest = trimmed.dropFirst("return".count).trimmingCharacters(in: .whitespaces)
                return try evaluateExpression(rest, localVars: localVars)
            }

            if let assignRange = findTopLevelAssignment(in: trimmed) {
                let varName = String(trimmed[trimmed.startIndex..<assignRange])
                    .trimmingCharacters(in: .whitespaces)
                if isValidIdentifier(varName) {
                    let exprStr = String(trimmed[trimmed.index(after: assignRange)...])
                        .trimmingCharacters(in: .whitespaces)
                    localVars[varName] = try evaluateExpression(exprStr, localVars: localVars)
                    continue
                }
            }

            _ = try evaluateExpression(trimmed, localVars: localVars)
        }
        throw CalcError.missingReturn
    }

    // MARK: - Tokenizer

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
                guard let value = Double(numStr) else { throw CalcError.invalidNumber(numStr) }
                tokens.append(LocatedToken(token: .number(value), range: tokenStart..<i))
                continue
            }

            if ch.isLetter || ch == "_" {
                var ident = ""
                while i < expr.endIndex && (expr[i].isLetter || expr[i].isNumber || expr[i] == "_") {
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
                throw CalcError.unknownCharacter(ch)
            }
            i = expr.index(after: i)
        }
        return tokens
    }
}

// MARK: - Errors

private enum CalcError: Error, LocalizedError {
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
