import Testing
@testable import sparkcalc

struct ResultFormatterTests {

    @Test func integer() {
        #expect(formatResult(42) == "42")
    }

    @Test func negativeInteger() {
        #expect(formatResult(-7) == "-7")
    }

    @Test func decimal() {
        #expect(formatResult(3.14) == "3.14")
    }

    @Test func trailingZeros() {
        #expect(formatResult(3.50000) == "3.5")
    }

    @Test func scientificNotation() {
        let result = formatResult(1e20)
        #expect(result.contains("e") || result.contains("E"))
    }

    @Test func nanValue() {
        #expect(formatResult(Double.nan) == "NaN")
    }

    @Test func positiveInfinity() {
        #expect(formatResult(Double.infinity) == "∞")
    }

    @Test func negativeInfinity() {
        #expect(formatResult(-Double.infinity) == "-∞")
    }

    @Test func largeInteger() {
        #expect(formatResult(1e14) == "100000000000000")
    }

    @Test func veryLargeInteger() {
        let result = formatResult(1e16)
        #expect(result.contains("e") || result.contains("E"))
    }

    @Test func formatZero() {
        #expect(formatResult(0.0) == "0")
    }

    @Test func formatNegativeZero() {
        #expect(formatResult(-0.0) == "-0")
    }

    @Test func formatNearThreshold() {
        #expect(formatResult(1e14) == "100000000000000")
        #expect(formatResult(1e15 - 1) == "999999999999999")
        let big = formatResult(1e15)
        #expect(big.contains("e") || big.contains("E"))
    }

    @Test func formatNegativeScientific() {
        let result = formatResult(-1e20)
        #expect(result.hasPrefix("-"))
        #expect(result.contains("e") || result.contains("E"))
    }

    @Test func formatVerySmall() {
        let result = formatResult(1e-20)
        #expect(result.contains("e") || result.contains("E"))
    }

    @Test func evaluateLinesWrapper() {
        let results = evaluateLines(["1 + 1", "2 * 3"])
        #expect(results == ["2", "6"])
    }
}
