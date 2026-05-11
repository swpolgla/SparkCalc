import Foundation

// MARK: - Engine

/// Core expression evaluator.
///
/// Parses and evaluates mathematical expressions using a recursive-descent parser.
/// Supports variables, user-defined multi-line functions, and a library of built-ins.
/// The engine evaluates line-by-line top-to-bottom, maintaining mutable state for
/// variables across the sheet.
class CalculatorEngine {

    static let builtInFunctions: Set<String> = [
        "sqrt", "cbrt", "abs", "ceil", "floor", "round",
        "sin", "cos", "tan", "asin", "acos", "atan", "atan2",
        "log", "log2", "log10", "exp", "pow",
        "min", "max", "hypot"
    ]

    static let builtInConstants: Set<String> = [
        "pi", "π", "e", "phi", "φ",
        "sqrt2", "sqrt3", "ln2", "ln10", "log2e", "log10e",
        "tau", "τ", "inf", "infinity", "nan",
        "c", "g", "G", "h", "k", "Na", "R"
    ]

    private static let defaultVariables: [String: Double] = [
        // Mathematical constants
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
        // Special floating-point values
        "inf":     Double.infinity,
        "infinity": Double.infinity,
        "nan":     Double.nan,
        // Physical constants
        "c":       299_792_458.0,       // speed of light (m/s)
        "g":       9.80665,             // standard gravity (m/s²)
        "G":       6.67430e-11,         // gravitational constant (m³·kg⁻¹·s⁻²)
        "h":       6.62607015e-34,      // Planck constant (J·Hz⁻¹)
        "k":       1.380649e-23,        // Boltzmann constant (J·K⁻¹)
        "Na":      6.02214076e23,       // Avogadro's number (mol⁻¹)
        "R":       8.314462618,         // ideal gas constant (J·mol⁻¹·K⁻¹)
    ]

    var variables: [String: Double] = CalculatorEngine.defaultVariables

    var functions: [String: FunctionDefinition] = [:]

    private var recursionDepth: Int = 0
    private let maxRecursionDepth = 256
    private let tokenizer = Tokenizer()

    /// Evaluates every line of the sheet and returns a formatted answer for each.
    ///
    /// This is a two-pass process:
    /// 1. `collectFunctions` identifies and registers all user-defined functions.
    /// 2. Each remaining line is evaluated top-to-bottom. Assignments mutate the
    ///    `variables` dictionary so subsequent lines can reference them.
    ///
    /// Blank lines, function definitions, and lines that throw errors produce `""`.
    @discardableResult
    func evaluate(lines: [String]) -> [String] {
        // Reset mutable state so the sheet text remains the sole source of truth.
        self.functions = [:]
        self.variables = Self.defaultVariables

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

    /// Scans the sheet for function definitions and registers them in `self.functions`.
    ///
    /// Returns an annotated copy of the input where every line is tagged as either
    /// part of a function block or an evaluable expression. This must run before
    /// `evaluate(lines:)` so that user-defined functions are available during expression
    /// parsing.
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

    /// Attempts to match a function declaration header such as `add(a, b) {`.
    ///
    /// Returns `nil` if the line does not conform to the expected pattern.
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

    /// Evaluates a single sheet line.
    ///
    /// If the line contains a top-level assignment (`name = expression`), the result
    /// is stored in `variables` under that name. Otherwise the line is treated as a
    /// pure expression.
    private func evaluateLine(_ line: String) throws -> Double {
        if let assignRange = findTopLevelAssignment(in: line) {
            let varName = String(line[line.startIndex..<assignRange]).trimmingCharacters(in: .whitespaces)
            if tokenizer.isValidIdentifier(varName) {
                let exprStr = String(line[line.index(after: assignRange)...]).trimmingCharacters(in: .whitespaces)
                let value = try evaluateExpression(exprStr, localVars: [:])
                variables[varName] = value
                return value
            }
        }
        return try evaluateExpression(line, localVars: [:])
    }

    /// Locates the first `=` that is not inside parentheses and not part of a
    /// comparison operator (`!=`, `<=`, `>=`, `==`).
    ///
    /// This heuristic distinguishes assignment from equality/comparison by tracking
    /// parenthetical nesting depth and inspecting the characters immediately before
    /// and after the `=`.
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

    // MARK: - Forwarding Methods

    /// Breaks an expression string into a sequence of `LocatedToken`s.
    func tokenize(_ expr: String) throws -> [LocatedToken] {
        try tokenizer.tokenize(expr)
    }

    /// Checks whether `s` is a legal identifier.
    func isValidIdentifier(_ s: String) -> Bool {
        tokenizer.isValidIdentifier(s)
    }

    // MARK: - Expression Evaluation (Recursive Descent Parser)

    /// Parses and evaluates an expression string.
    ///
    /// The parser implements the following precedence (lowest to highest):
    /// 1. Addition / subtraction (`+`, `-`)
    /// 2. Multiplication / division / modulo (`*`, `/`, `%`)
    /// 3. Unary plus / minus
    /// 4. Exponentiation (`^`) — right-associative via `parseUnary` on the RHS
    /// 5. Postfix percentage (`%`)
    /// 6. Primary: numbers, identifiers (variables / functions), parenthesized expressions
    ///
    /// `localVars` shadows `variables`; identifiers are resolved in that order.
    func evaluateExpression(_ expr: String, localVars: [String: Double]) throws -> Double {
        let locatedTokens = try tokenizer.tokenize(expr)
        let tokens = locatedTokens.map { $0.token }
        var pos = 0
        let result = try parseAddSub(tokens: tokens, pos: &pos, localVars: localVars)
        if pos != tokens.count {
            throw CalculatorError.unexpectedToken(tokens[pos].description)
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
        guard pos < tokens.count else { throw CalculatorError.unexpectedEndOfExpression }

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
                    throw CalculatorError.missingClosingParen
                }
                pos += 1
                return try callFunction(name: name, args: args)
            }
            if let val = localVars[name] { return val }
            if let val = variables[name]  { return val }
            throw CalculatorError.undefinedVariable(name)

        case .lparen:
            pos += 1
            let val = try parseAddSub(tokens: tokens, pos: &pos, localVars: localVars)
            guard pos < tokens.count, case .rparen = tokens[pos] else {
                throw CalculatorError.missingClosingParen
            }
            pos += 1
            return val

        case .rparen:
            throw CalculatorError.unexpectedToken(")")

        default:
            throw CalculatorError.unexpectedToken(tokens[pos].description)
        }
    }

    // MARK: - Function Invocation

    /// Dispatches a function call to either a built-in implementation or a user-defined function.
    ///
    /// Built-ins are matched by hard-coded `case` labels. User-defined functions are looked up
    /// in `self.functions`, their parameters are bound to the supplied arguments, and the body
    /// is evaluated line-by-line.
    private func callFunction(name: String, args: [Double]) throws -> Double {
        switch name {
        case "sqrt":  guard args.count == 1 else { throw CalculatorError.wrongArgCount(name) }; return sqrt(args[0])
        case "cbrt":  guard args.count == 1 else { throw CalculatorError.wrongArgCount(name) }; return cbrt(args[0])
        case "abs":   guard args.count == 1 else { throw CalculatorError.wrongArgCount(name) }; return abs(args[0])
        case "ceil":  guard args.count == 1 else { throw CalculatorError.wrongArgCount(name) }; return ceil(args[0])
        case "floor": guard args.count == 1 else { throw CalculatorError.wrongArgCount(name) }; return floor(args[0])
        case "round": guard args.count == 1 else { throw CalculatorError.wrongArgCount(name) }; return round(args[0])
        case "sin":   guard args.count == 1 else { throw CalculatorError.wrongArgCount(name) }; return sin(args[0])
        case "cos":   guard args.count == 1 else { throw CalculatorError.wrongArgCount(name) }; return cos(args[0])
        case "tan":   guard args.count == 1 else { throw CalculatorError.wrongArgCount(name) }; return tan(args[0])
        case "asin":  guard args.count == 1 else { throw CalculatorError.wrongArgCount(name) }; return asin(args[0])
        case "acos":  guard args.count == 1 else { throw CalculatorError.wrongArgCount(name) }; return acos(args[0])
        case "atan":  guard args.count == 1 else { throw CalculatorError.wrongArgCount(name) }; return atan(args[0])
        case "atan2": guard args.count == 2 else { throw CalculatorError.wrongArgCount(name) }; return atan2(args[0], args[1])
        case "log":   guard args.count == 1 else { throw CalculatorError.wrongArgCount(name) }; return log(args[0])
        case "log2":  guard args.count == 1 else { throw CalculatorError.wrongArgCount(name) }; return log2(args[0])
        case "log10": guard args.count == 1 else { throw CalculatorError.wrongArgCount(name) }; return log10(args[0])
        case "exp":   guard args.count == 1 else { throw CalculatorError.wrongArgCount(name) }; return exp(args[0])
        case "pow":   guard args.count == 2 else { throw CalculatorError.wrongArgCount(name) }; return pow(args[0], args[1])
        case "min":   guard args.count >= 2, let result = args.min() else { throw CalculatorError.wrongArgCount(name) }; return result
        case "max":   guard args.count >= 2, let result = args.max() else { throw CalculatorError.wrongArgCount(name) }; return result
        case "hypot": guard args.count == 2 else { throw CalculatorError.wrongArgCount(name) }; return hypot(args[0], args[1])
        default: break
        }

        guard let def = functions[name] else { throw CalculatorError.undefinedFunction(name) }
        guard args.count == def.parameters.count else { throw CalculatorError.wrongArgCount(name) }

        recursionDepth += 1
        defer { recursionDepth -= 1 }
        guard recursionDepth <= maxRecursionDepth else {
            throw CalculatorError.recursionLimitExceeded
        }

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
            if tokenizer.isValidIdentifier(varName) {
                    let exprStr = String(trimmed[trimmed.index(after: assignRange)...])
                        .trimmingCharacters(in: .whitespaces)
                    localVars[varName] = try evaluateExpression(exprStr, localVars: localVars)
                    continue
                }
            }

            _ = try evaluateExpression(trimmed, localVars: localVars)
        }
        throw CalculatorError.missingReturn
    }

    // MARK: - Tokenizer

}
