import Testing
@testable import sparkcalc

struct CalculatorEngineTests {

    // MARK: - Basic Arithmetic

    @Test func addition() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["1 + 1"])
        #expect(results == ["2"])
    }

    @Test func subtraction() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["5 - 3"])
        #expect(results == ["2"])
    }

    @Test func multiplication() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["3 * 4"])
        #expect(results == ["12"])
    }

    @Test func division() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["10 / 4"])
        #expect(results == ["2.5"])
    }

    @Test func operatorPrecedence() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["1 + 2 * 3"])
        #expect(results == ["7"])
    }

    @Test func parentheses() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["(1 + 2) * 3"])
        #expect(results == ["9"])
    }

    // MARK: - Unary Operators

    @Test func unaryMinus() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["-5 + 3"])
        #expect(results == ["-2"])
    }

    @Test func unaryPlus() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["+5"])
        #expect(results == ["5"])
    }

    // MARK: - Exponentiation

    @Test func exponentiation() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["2 ^ 3"])
        #expect(results == ["8"])
    }

    @Test func rightAssociativeExponentiation() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["2 ^ 3 ^ 2"])
        #expect(results == ["512"])
    }

    // MARK: - Percentage

    @Test func postfixPercentage() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["50%"])
        #expect(results == ["0.5"])
    }

    @Test func moduloOperator() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["10 % 3"])
        #expect(results == ["1"])
    }

    // MARK: - Variables

    @Test func variableAssignment() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: [
            "a = 5",
            "a * 2"
        ])
        #expect(results == ["5", "10"])
    }

    @Test func variableRedefinition() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: [
            "a = 5",
            "a = 10",
            "a"
        ])
        #expect(results == ["5", "10", "10"])
    }

    @Test func builtInConstant() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["pi"])
        #expect(results.first?.hasPrefix("3.14") == true)
    }

    // MARK: - Functions

    @Test func builtInFunction() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["sqrt(16)"])
        #expect(results == ["4"])
    }

    @Test func userDefinedFunction() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: [
            "add(a, b) {",
            "    return a + b",
            "}",
            "add(3, 4)"
        ])
        #expect(results == ["", "", "", "7"])
    }

    @Test func recursionLimit() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: [
            "f() {",
            "    return f()",
            "}",
            "f()"
        ])
        #expect(results[3] == "")
    }

    // MARK: - Edge Cases

    @Test func blankLine() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: [""])
        #expect(results == [""])
    }

    @Test func invalidExpression() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["1 + * 2"])
        #expect(results == [""])
    }

    @Test func divisionByZero() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["1 / 0"])
        #expect(results == ["∞"])
    }

    @Test func stateReset() {
        let engine = CalculatorEngine()
        _ = engine.evaluate(lines: ["a = 5"])
        let results = engine.evaluate(lines: ["a"])
        #expect(results == [""])
    }

    // MARK: - Built-in Functions

    @Test func trigFunctions() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["sin(0)"]) == ["0"])
        #expect(engine.evaluate(lines: ["cos(0)"]) == ["1"])
        #expect(engine.evaluate(lines: ["tan(0)"]) == ["0"])
        #expect(engine.evaluate(lines: ["asin(0)"]) == ["0"])
        #expect(engine.evaluate(lines: ["acos(1)"]) == ["0"])
        #expect(engine.evaluate(lines: ["atan(0)"]) == ["0"])
        #expect(engine.evaluate(lines: ["atan2(0, 1)"]) == ["0"])
    }

    @Test func logAndExpFunctions() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["log(1)"]) == ["0"])
        #expect(engine.evaluate(lines: ["log2(8)"]) == ["3"])
        #expect(engine.evaluate(lines: ["log10(100)"]) == ["2"])
        #expect(engine.evaluate(lines: ["exp(0)"]) == ["1"])
        #expect(engine.evaluate(lines: ["log(0)"]) == ["-∞"])
        #expect(engine.evaluate(lines: ["log(-1)"]) == ["NaN"])
    }

    @Test func powerFunctions() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["pow(2, 3)"]) == ["8"])
        #expect(engine.evaluate(lines: ["pow(2, -1)"]) == ["0.5"])
        #expect(engine.evaluate(lines: ["cbrt(27)"]) == ["3"])
        #expect(engine.evaluate(lines: ["cbrt(-8)"]) == ["-2"])
    }

    @Test func roundingFunctions() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["ceil(2.1)"]) == ["3"])
        #expect(engine.evaluate(lines: ["floor(2.9)"]) == ["2"])
        #expect(engine.evaluate(lines: ["round(2.5)"]) == ["3"])
    }

    @Test func aggregationFunctions() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["abs(-5)"]) == ["5"])
        #expect(engine.evaluate(lines: ["min(3, 7, 2)"]) == ["2"])
        #expect(engine.evaluate(lines: ["max(3, 7, 2)"]) == ["7"])
        #expect(engine.evaluate(lines: ["hypot(3, 4)"]) == ["5"])
    }

    @Test func builtInWrongArgCount() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["sqrt()"]) == [""])
        #expect(engine.evaluate(lines: ["sqrt(1, 2)"]) == [""])
        #expect(engine.evaluate(lines: ["min(1)"]) == [""])
        #expect(engine.evaluate(lines: ["atan2(1)"]) == [""])
        #expect(engine.evaluate(lines: ["pow(2)"]) == [""])
    }

    // MARK: - Built-in Constants

    @Test func mathematicalConstants() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["e"]).first?.hasPrefix("2.718") == true)
        #expect(engine.evaluate(lines: ["phi"]).first?.hasPrefix("1.618") == true)
        #expect(engine.evaluate(lines: ["τ"]).first?.hasPrefix("6.283") == true)
    }

    @Test func specialConstants() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["inf"]) == ["∞"])
        #expect(engine.evaluate(lines: ["infinity"]) == ["∞"])
        #expect(engine.evaluate(lines: ["nan"]) == ["NaN"])
    }

    @Test func physicalConstants() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["c"]) == ["299792458"])
        #expect(engine.evaluate(lines: ["g"]) == ["9.80665"])
        #expect(engine.evaluate(lines: ["G"]).first?.hasPrefix("6.6743") == true)
        #expect(engine.evaluate(lines: ["h"]).first?.hasPrefix("6.62607") == true)
        #expect(engine.evaluate(lines: ["k"]).first?.hasPrefix("1.380649") == true)
        #expect(engine.evaluate(lines: ["Na"]).first?.hasPrefix("6.02214") == true)
        #expect(engine.evaluate(lines: ["R"]).first?.hasPrefix("8.31446") == true)
    }

    // MARK: - Error Throwing

    @Test func undefinedVariableThrows() {
        let engine = CalculatorEngine()
        #expect(throws: CalculatorError.undefinedVariable("x")) {
            try engine.evaluateExpression("x", localVars: [:])
        }
    }

    @Test func undefinedFunctionThrows() {
        let engine = CalculatorEngine()
        #expect(throws: CalculatorError.undefinedFunction("foo")) {
            try engine.evaluateExpression("foo()", localVars: [:])
        }
    }

    @Test func wrongArgCountThrows() {
        let engine = CalculatorEngine()
        #expect(throws: CalculatorError.wrongArgCount("sqrt")) {
            try engine.evaluateExpression("sqrt(1, 2)", localVars: [:])
        }
    }

    @Test func missingClosingParenThrows() {
        let engine = CalculatorEngine()
        #expect(throws: CalculatorError.missingClosingParen) {
            try engine.evaluateExpression("(1 + 2", localVars: [:])
        }
    }

    @Test func unexpectedEndThrows() {
        let engine = CalculatorEngine()
        #expect(throws: CalculatorError.unexpectedEndOfExpression) {
            try engine.evaluateExpression("1 + ", localVars: [:])
        }
    }

    @Test func unexpectedTokenThrows() {
        let engine = CalculatorEngine()
        #expect(throws: CalculatorError.unexpectedToken("*")) {
            try engine.evaluateExpression("* 5", localVars: [:])
        }
    }

    @Test func unknownCharacterThrows() {
        let engine = CalculatorEngine()
        #expect(throws: CalculatorError.unknownCharacter("@")) {
            try engine.evaluateExpression("5 @ 3", localVars: [:])
        }
    }

    @Test func errorDescriptions() {
        #expect(CalculatorError.undefinedVariable("x").errorDescription == "Undefined variable: 'x'")
        #expect(CalculatorError.undefinedFunction("f").errorDescription == "Undefined function: 'f'")
        #expect(CalculatorError.wrongArgCount("sin").errorDescription == "Wrong argument count for function: 'sin'")
        #expect(CalculatorError.missingReturn.errorDescription == "Function did not return a value")
        #expect(CalculatorError.recursionLimitExceeded.errorDescription == "Recursion limit exceeded")
        #expect(CalculatorError.unexpectedEndOfExpression.errorDescription == "Unexpected end of expression")
        #expect(CalculatorError.missingClosingParen.errorDescription == "Missing closing parenthesis")
        #expect(CalculatorError.invalidNumber("1e").errorDescription == "Invalid number: '1e'")
        #expect(CalculatorError.unknownCharacter("$").errorDescription == "Unknown character: '$'")
        #expect(CalculatorError.unexpectedToken("+").errorDescription == "Unexpected token: '+'")
    }

    // MARK: - Function Features

    @Test func functionLocalVariables() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: [
            "f() {",
            "    x = 10",
            "    return x + 5",
            "}",
            "f()"
        ])
        #expect(results == ["", "", "", "", "15"])
    }

    @Test func parameterShadowing() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: [
            "x = 100",
            "f(x) {",
            "    return x + 1",
            "}",
            "f(5)"
        ])
        #expect(results == ["100", "", "", "", "6"])
    }

    @Test func nestedUserDefinedCalls() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: [
            "double(x) {",
            "    return x * 2",
            "}",
            "inc(x) {",
            "    return double(x) + 1",
            "}",
            "inc(3)"
        ])
        #expect(results == ["", "", "", "", "", "", "7"])
    }

    @Test func userFunctionCallsBuiltIn() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: [
            "mySqrt(x) {",
            "    return sqrt(x)",
            "}",
            "mySqrt(16)"
        ])
        #expect(results == ["", "", "", "4"])
    }

    @Test func functionMultipleStatements() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: [
            "f(x) {",
            "    a = x + 1",
            "    b = a * 2",
            "    return b",
            "}",
            "f(3)"
        ])
        #expect(results == ["", "", "", "", "", "8"])
    }

    @Test func functionLocalsAreIsolated() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: [
            "x = 1",
            "f() {",
            "    x = 999",
            "    return x",
            "}",
            "f()",
            "x"
        ])
        #expect(results == ["1", "", "", "", "", "999", "1"])
    }

    @Test func builtInShadowsUserFunction() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: [
            "sqrt(x) {",
            "    return x + 1",
            "}",
            "sqrt(16)"
        ])
        #expect(results[3] == "4") // built-in sqrt wins
    }

    @Test func userDefinedWrongArgCount() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: [
            "add(a, b) {",
            "    return a + b",
            "}",
            "add(1)"
        ])
        #expect(results[3] == "")
    }

    @Test func missingReturnThrows() {
        let engine = CalculatorEngine()
        _ = engine.evaluate(lines: [
            "f() {",
            "    x = 1",
            "}"
        ])
        #expect(throws: CalculatorError.missingReturn) {
            try engine.evaluateExpression("f()", localVars: [:])
        }
    }

    // MARK: - Parser Edge Cases

    @Test func extraClosingParen() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["(1 + 2))"]) == [""])
    }

    @Test func missingClosingParen() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["(1 + 2"]) == [""])
        #expect(engine.evaluate(lines: ["sqrt(16"]) == [""])
    }

    @Test func emptyParentheses() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["()"]) == [""])
    }

    @Test func doubleUnaryOperators() {
        let engine = CalculatorEngine()
        // Multiple unary operators are not supported by the parser;
        // only a single leading + or - is handled.
        #expect(engine.evaluate(lines: ["--5"]) == [""])
        #expect(engine.evaluate(lines: ["-+5"]) == [""])
        #expect(engine.evaluate(lines: ["+-5"]) == [""])
        #expect(engine.evaluate(lines: ["-5"]) == ["-5"])
        #expect(engine.evaluate(lines: ["+5"]) == ["5"])
    }

    @Test func loneOperator() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["+"]) == [""])
        #expect(engine.evaluate(lines: ["1 + "]) == [""])
    }

    @Test func whitespaceOnlyExpression() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["   "]) == [""])
    }

    @Test func exponentiationWithNegativeBase() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["-2 ^ 2"]) == ["-4"])
        #expect(engine.evaluate(lines: ["(-2) ^ 2"]) == ["4"])
        #expect(engine.evaluate(lines: ["(-2) ^ 3"]) == ["-8"])
    }

    // MARK: - Variable Edge Cases

    @Test func overwriteBuiltInConstant() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["pi = 3", "pi"])
        #expect(results == ["3", "3"])
    }

    @Test func assignmentWithExpression() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: [
            "a = 2 + 3",
            "a * 2"
        ])
        #expect(results == ["5", "10"])
    }

    @Test func assignmentInvalidIdentifier() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["123 = 5"])
        #expect(results == [""])
    }

    @Test func unicodeConstantReadable() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["π"]).first?.hasPrefix("3.14") == true)
    }

    @Test func forwardReferenceVariable() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: [
            "a + b",
            "a = 1",
            "b = 2"
        ])
        #expect(results == ["", "1", "2"])
    }

    @Test func variableShadowsFunctionName() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: ["sqrt = 10", "sqrt"])
        #expect(results == ["10", "10"])
    }

    // MARK: - Math Edge Cases

    @Test func moduloByZero() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["10 % 0"]) == ["NaN"])
    }

    @Test func zeroDividedByZero() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["0 / 0"]) == ["NaN"])
    }

    @Test func sqrtNegative() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["sqrt(-1)"]) == ["NaN"])
    }

    @Test func negativeModulo() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["-10 % 3"]) == ["-1"])
        // Note: `10 % -3` parses incorrectly because `%` after `10` is
        // consumed as postfix percentage before `-3` is seen.
        // Testing via a parenthesized expression instead:
        #expect(engine.evaluate(lines: ["10 % (-3)"]) == ["1"])
    }

    @Test func powEdgeCases() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["0 ^ 0"]) == ["1"])
        #expect(engine.evaluate(lines: ["(-1) ^ 0.5"]) == ["NaN"])
        #expect(engine.evaluate(lines: ["2 ^ -1"]) == ["0.5"])
    }

    @Test func extremeValues() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["1e308 * 10"]) == ["∞"])
        #expect(engine.evaluate(lines: ["1e-308 / 10"]).first?.hasPrefix("1e") == true)
    }

    @Test func scientificNotationInput() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["1e3 + 2E2"]) == ["1200"])
        #expect(engine.evaluate(lines: ["1.5e-2 * 100"]) == ["1.5"])
    }

    @Test func percentageInCompoundExpression() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["100 * 50%"]) == ["50"])
        #expect(engine.evaluate(lines: ["10 + 20%"]) == ["10.2"])
        #expect(engine.evaluate(lines: ["(10 + 20)%"]) == ["0.3"])
    }

    @Test func doublePercentage() {
        let engine = CalculatorEngine()
        #expect(engine.evaluate(lines: ["50%%"]) == ["0.005"])
    }

    // MARK: - Engine Lifecycle

    @Test func functionStateReset() {
        let engine = CalculatorEngine()
        _ = engine.evaluate(lines: [
            "f() {",
            "    return 1",
            "}"
        ])
        let results = engine.evaluate(lines: ["f()"])
        #expect(results == [""])
    }

    @Test func parseFunctionHeader() {
        let engine = CalculatorEngine()
        let h = engine.tryParseFunctionHeader("add(a, b) {")
        #expect(h?.name == "add")
        #expect(h?.parameters == ["a", "b"])
    }

    @Test func parseFunctionHeaderNoMatch() {
        let engine = CalculatorEngine()
        #expect(engine.tryParseFunctionHeader("add(a, b)") == nil)
        #expect(engine.tryParseFunctionHeader("add (a, b) {") == nil)
    }

    @Test func findTopLevelAssignment() {
        let engine = CalculatorEngine()
        #expect(engine.findTopLevelAssignment(in: "a = 1") != nil)
        #expect(engine.findTopLevelAssignment(in: "1 == 1") == nil)
        #expect(engine.findTopLevelAssignment(in: "1 != 1") == nil)
        #expect(engine.findTopLevelAssignment(in: "f(a = 1)") == nil)
    }

    @Test func functionReadsGlobalVariable() {
        let engine = CalculatorEngine()
        let results = engine.evaluate(lines: [
            "x = 5",
            "f(a) {",
            "    return a + x",
            "}",
            "f(3)"
        ])
        #expect(results == ["5", "", "", "", "8"])
    }
}
