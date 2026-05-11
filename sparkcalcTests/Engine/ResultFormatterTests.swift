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
}
