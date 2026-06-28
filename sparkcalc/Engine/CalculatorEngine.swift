import Foundation

// MARK: - Engine

/// Core expression evaluator.
///
/// Parses and evaluates mathematical expressions using a recursive-descent parser.
/// Supports variables, user-defined multi-line functions, and a library of built-ins.
/// The engine evaluates line-by-line top-to-bottom, maintaining mutable state for
/// variables across the sheet.
final class CalculatorEngine {
    /// Table-driven builtin function dispatch.
    /// `arity` is `nil` for variadic functions (minimum 2 args, e.g. `min`/`max`).
    /// This is the single source of truth — `builtInFunctions` is derived from it.
    private static let builtIns: [String: (arity: Int?, fn: ([Double]) throws -> Double)] = [
        "sqrt": (1, { args in sqrt(args[0]) }),
        "cbrt": (1, { args in cbrt(args[0]) }),
        "abs": (1, { args in abs(args[0]) }),
        "ceil": (1, { args in ceil(args[0]) }),
        "floor": (1, { args in floor(args[0]) }),
        "round": (1, { args in round(args[0]) }),
        "sin": (1, { args in sin(args[0]) }),
        "cos": (1, { args in cos(args[0]) }),
        "tan": (1, { args in tan(args[0]) }),
        "asin": (1, { args in asin(args[0]) }),
        "acos": (1, { args in acos(args[0]) }),
        "atan": (1, { args in atan(args[0]) }),
        "atan2": (2, { args in atan2(args[0], args[1]) }),
        "log": (1, { args in log(args[0]) }),
        "log2": (1, { args in log2(args[0]) }),
        "log10": (1, { args in log10(args[0]) }),
        "exp": (1, { args in exp(args[0]) }),
        "pow": (2, { args in pow(args[0], args[1]) }),
        "min": (nil, { args in args.min()! }),
        "max": (nil, { args in args.max()! }),
        "hypot": (2, { args in hypot(args[0], args[1]) })
    ]

    static let builtInFunctions: Set<String> = Set(builtIns.keys)

    static let builtInConstants: Set<String> = [
        "pi", "π", "e", "phi", "φ",
        "sqrt2", "sqrt3", "ln2", "ln10", "log2e", "log10e",
        "tau", "τ", "inf", "infinity", "nan",
        "c", "g", "G", "h", "k", "Na", "R"
    ]

    private static let defaultVariables: [String: Double] = [
        // Mathematical constants
        "pi": Double.pi,
        "π": Double.pi,
        "e": M_E,
        "phi": 1.6180339887498948482,
        "φ": 1.6180339887498948482,
        "sqrt2": 2.0.squareRoot(),
        "sqrt3": 3.0.squareRoot(),
        "ln2": log(2.0),
        "ln10": log(10.0),
        "log2e": log2(M_E),
        "log10e": log10(M_E),
        "tau": 2.0 * Double.pi,
        "τ": 2.0 * Double.pi,
        // Special floating-point values
        "inf": Double.infinity,
        "infinity": Double.infinity,
        "nan": Double.nan,
        // Physical constants
        "c": 299_792_458.0, // speed of light (m/s)
        "g": 9.80665, // standard gravity (m/s²)
        "G": 6.67430e-11, // gravitational constant (m³·kg⁻¹·s⁻²)
        "h": 6.62607015e-34, // Planck constant (J·Hz⁻¹)
        "k": 1.380649e-23, // Boltzmann constant (J·K⁻¹)
        "Na": 6.02214076e23, // Avogadro's number (mol⁻¹)
        "R": 8.314462618 // ideal gas constant (J·mol⁻¹·K⁻¹)
    ]

    /// Precompiled regex for matching function declaration headers like `add(a, b) {`.
    /// Hoisted to a static to avoid recompiling on every call (hot path: invoked
    /// once per line per keystroke during both evaluation and syntax highlighting).
    private static let functionHeaderRegex: NSRegularExpression = {
        let pattern = #"^([a-zA-Z_][a-zA-Z0-9_]*)\(([^)]*)\)\s*\{$"#
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: pattern)
    }()

    private(set) var variables: [String: Double] = CalculatorEngine.defaultVariables

    private(set) var functions: [String: FunctionDefinition] = [:]

    private var recursionDepth: Int = 0
    /// The maximum recursion depth for user-defined functions.
    /// Exceeding this throws `CalculatorError.recursionLimitExceeded`.
    /// Documented in AGENTS.md as a deliberate limit to prevent stack overflow.
    private static let maxRecursionDepth = 256
    private let tokenizer = Tokenizer()

    /// Memoization cache for `evaluate(lines:)`. `Sheet.updateAnswers()` and
    /// `SyntaxHighlighter.performHighlighting` both invoke it with identical
    /// lines per keystroke; the second call short-circuits to cached results,
    /// avoiding a redundant full parse. Safe because evaluation is deterministic
    /// and state is fully rebuilt on every cache miss.
    private var lastEvaluatedLines: [String]?
    private var lastResults: [String]?

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
        if let cached = lastEvaluatedLines, cached == lines, let results = lastResults {
            return results
        }

        // Reset mutable state so the sheet text remains the sole source of truth.
        functions = [:]
        variables = Self.defaultVariables
        recursionDepth = 0

        let annotated = collectFunctions(from: lines)
        var results: [String] = []

        for entry in annotated {
            switch entry {
            case .functionLine:
                results.append("")

            case let .evaluable(raw):
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else {
                    results.append("")
                    continue
                }
                do {
                    let value = try evaluateLine(trimmed)
                    results.append(formatResult(value))
                } catch is CalculatorError {
                    results.append("")
                } catch {
                    #if DEBUG
                        print("Unexpected error during evaluation: \(error)")
                    #endif
                    results.append("")
                }
            }
        }
        lastEvaluatedLines = lines
        lastResults = results
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

            if let funcDef = tryParseFunctionHeader(trimmed),
               let closingIndex = lines[(i + 1)...].firstIndex(where: {
                   $0.trimmingCharacters(in: .whitespaces) == "}"
               })
            {
                annotated.append(.functionLine)
                i += 1

                var bodyLines: [String] = []

                while i <= closingIndex {
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
        let lineLength = (line as NSString).length
        guard let match = Self.functionHeaderRegex.firstMatch(in: line, range: NSRange(location: 0, length: lineLength)),
              let nameRange = Range(match.range(at: 1), in: line),
              let paramsRange = Range(match.range(at: 2), in: line)
        else {
            return nil
        }
        let name = String(line[nameRange])
        let rawParams = String(line[paramsRange])
        let params: [String]
        if rawParams.trimmingCharacters(in: .whitespaces).isEmpty {
            params = []
        } else {
            params = rawParams
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard params.allSatisfy(tokenizer.isValidIdentifier),
                  Set(params).count == params.count
            else {
                return nil
            }
        }
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
            if ch == "(" { depth += 1 } else if ch == ")" { depth -= 1 } else if ch == "=", depth == 0 {
                let nextIdx = line.index(after: i)
                let next: Character = nextIdx < line.endIndex ? line[nextIdx] : "\0"
                if prev != "!", prev != "<", prev != ">", prev != "=", next != "=" {
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
        let tokens = locatedTokens.map(\.token)
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
            if case let .op(op) = tokens[pos], op == .plus || op == .minus {
                pos += 1
                let right = try parseMulDiv(tokens: tokens, pos: &pos, localVars: localVars)
                left = op == .plus ? left + right : left - right
            } else { break }
        }
        return left
    }

    private func parseMulDiv(tokens: [Token], pos: inout Int, localVars: [String: Double]) throws -> Double {
        var left = try parseUnary(tokens: tokens, pos: &pos, localVars: localVars)
        while pos < tokens.count {
            if case let .op(op) = tokens[pos], op == .multiply || op == .divide || op == .percent {
                pos += 1
                let right = try parseUnary(tokens: tokens, pos: &pos, localVars: localVars)
                switch op {
                case .multiply: left *= right
                case .divide: left /= right
                case .percent: left = left.truncatingRemainder(dividingBy: right)
                default: break
                }
            } else { break }
        }
        return left
    }

    private func parseUnary(tokens: [Token], pos: inout Int, localVars: [String: Double]) throws -> Double {
        if pos < tokens.count, case let .op(op) = tokens[pos], op == .minus || op == .plus {
            pos += 1
            let val = try parsePower(tokens: tokens, pos: &pos, localVars: localVars)
            return op == .minus ? -val : val
        }
        return try parsePower(tokens: tokens, pos: &pos, localVars: localVars)
    }

    private func parsePower(tokens: [Token], pos: inout Int, localVars: [String: Double]) throws -> Double {
        let base = try parsePostfix(tokens: tokens, pos: &pos, localVars: localVars)
        if pos < tokens.count, case let .op(op) = tokens[pos], op == .power {
            pos += 1
            let exp = try parseUnary(tokens: tokens, pos: &pos, localVars: localVars)
            return pow(base, exp)
        }
        return base
    }

    private func parsePostfix(tokens: [Token], pos: inout Int, localVars: [String: Double]) throws -> Double {
        var val = try parsePrimary(tokens: tokens, pos: &pos, localVars: localVars)
        while pos < tokens.count, case let .op(op) = tokens[pos], op == .percent {
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
            val /= 100.0
            pos += 1
        }
        return val
    }

    private func parsePrimary(tokens: [Token], pos: inout Int, localVars: [String: Double]) throws -> Double {
        guard pos < tokens.count else { throw CalculatorError.unexpectedEndOfExpression }

        switch tokens[pos] {
        case let .number(v):
            pos += 1
            return v

        case let .ident(name):
            pos += 1
            if pos < tokens.count, case .lparen = tokens[pos] {
                pos += 1
                var args: [Double] = []
                if pos < tokens.count, case .rparen = tokens[pos] {
                    // empty arg list
                } else {
                    try args.append(parseAddSub(tokens: tokens, pos: &pos, localVars: localVars))
                    while pos < tokens.count, case .comma = tokens[pos] {
                        pos += 1
                        try args.append(parseAddSub(tokens: tokens, pos: &pos, localVars: localVars))
                    }
                }
                guard pos < tokens.count, case .rparen = tokens[pos] else {
                    throw CalculatorError.missingClosingParen
                }
                pos += 1
                return try callFunction(name: name, args: args)
            }
            if let val = localVars[name] { return val }
            if let val = variables[name] { return val }
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
        if let builtin = Self.builtIns[name] {
            if let arity = builtin.arity {
                guard args.count == arity else { throw CalculatorError.wrongArgCount(name) }
            } else {
                guard args.count >= 2 else { throw CalculatorError.wrongArgCount(name) }
            }
            return try builtin.fn(args)
        }

        guard let def = functions[name] else { throw CalculatorError.undefinedFunction(name) }
        guard args.count == def.parameters.count else { throw CalculatorError.wrongArgCount(name) }

        recursionDepth += 1
        defer { recursionDepth -= 1 }
        guard recursionDepth <= Self.maxRecursionDepth else {
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

            let returnSuffix = trimmed.dropFirst(min("return".count, trimmed.count))
            if trimmed == "return" || (trimmed.hasPrefix("return") && returnSuffix.first?.isWhitespace == true) {
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
