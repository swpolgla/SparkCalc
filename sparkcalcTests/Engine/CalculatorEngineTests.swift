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
}
