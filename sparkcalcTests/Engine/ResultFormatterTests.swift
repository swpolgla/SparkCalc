import Testing
@testable import sparkcalc

struct ResultFormatterTests {

    // MARK: - Integer Formatting

    @Test func integer() {
        #expect(formatResult(42) == "42")
    }

    @Test func negativeInteger() {
        #expect(formatResult(-7) == "-7")
    }

    @Test func largeInteger() {
        #expect(formatResult(1e14) == "100000000000000")
    }

    @Test func formatZero() {
        #expect(formatResult(0.0) == "0")
    }

    @Test func formatNegativeZero() {
        #expect(formatResult(-0.0) == "-0")
    }

    // MARK: - Decimal Formatting

    @Test func decimal() {
        #expect(formatResult(3.14) == "3.14")
    }

    @Test func trailingZeros() {
        #expect(formatResult(3.50000) == "3.5")
    }

    @Test func fractionPrecision() {
        #expect(formatResult(1.0 / 3.0) == "0.333333333333333")
    }

    // MARK: - Scientific Notation (exact strings, not vacuous contains checks)

    @Test func scientificNotation() {
        #expect(formatResult(1e20) == "1e+20")
    }

    @Test func veryLargeInteger() {
        #expect(formatResult(1e16) == "1e+16")
    }

    @Test func formatNearThreshold() {
        #expect(formatResult(1e14) == "100000000000000")
        #expect(formatResult(1e15 - 1) == "999999999999999")
        #expect(formatResult(1e15) == "1e+15")
    }

    @Test func formatNegativeScientific() {
        #expect(formatResult(-1e20) == "-1e+20")
    }

    @Test func formatVerySmall() {
        #expect(formatResult(1e-20) == "1e-20")
    }

    // MARK: - Special Values

    @Test func nanValue() {
        #expect(formatResult(Double.nan) == "NaN")
    }

    @Test func positiveInfinity() {
        #expect(formatResult(Double.infinity) == "∞")
    }

    @Test func negativeInfinity() {
        #expect(formatResult(-Double.infinity) == "-∞")
    }

    // MARK: - evaluateLines Wrapper

    @Test func evaluateLinesWrapper() {
        let results = evaluateLines(["1 + 1", "2 * 3"])
        #expect(results == ["2", "6"])
    }
}
