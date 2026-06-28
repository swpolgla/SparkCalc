import Foundation
@testable import sparkcalc
import Testing

struct AutocompleteProviderTests {
    private let provider = AutocompleteProvider()

    @Test func suggestsVariablesFromEarlierLinesOnly() {
        let text = "subtotal = 12\nfutureValue = 20\nsub"
        let suggestions = provider.suggestions(
            in: text,
            cursorLocation: (text as NSString).length,
            engine: CalculatorEngine(),
            minimumPrefixLength: 2
        )

        #expect(suggestions.contains { $0.name == "subtotal" })
        #expect(!suggestions.contains { $0.name == "futureValue" })
    }

    @Test func includesBuiltIns() {
        let text = "sq"
        let suggestions = provider.suggestions(
            in: text,
            cursorLocation: (text as NSString).length,
            engine: CalculatorEngine(),
            minimumPrefixLength: 2
        )

        #expect(suggestions.contains { $0.name == "sqrt" && $0.insertionText == "sqrt(value)" })
        #expect(suggestions.contains { $0.name == "sqrt2" })
    }

    @Test func insertsUserFunctionSignature() {
        let text = "payment(principal, rate, months) {\nreturn principal\n}\npa"
        let suggestions = provider.suggestions(
            in: text,
            cursorLocation: (text as NSString).length,
            engine: CalculatorEngine(),
            minimumPrefixLength: 2
        )

        #expect(suggestions.first?.name == "payment")
        #expect(suggestions.first?.insertionText == "payment(principal, rate, months)")
    }

    @Test func excludesVariablesLocalToFunctions() {
        let text = "calculate() {\ntemporary = 42\nreturn temporary\n}\ntem"
        let suggestions = provider.suggestions(
            in: text,
            cursorLocation: (text as NSString).length,
            engine: CalculatorEngine(),
            minimumPrefixLength: 2
        )

        #expect(!suggestions.contains { $0.name == "temporary" })
    }

    @Test func respectsMinimumPrefixLength() {
        let text = "sqrt2 = 2\ns"
        let suggestions = provider.suggestions(
            in: text,
            cursorLocation: (text as NSString).length,
            engine: CalculatorEngine(),
            minimumPrefixLength: 2
        )

        #expect(suggestions.isEmpty)
    }

    @Test func completionRangeSupportsDottedIdentifiers() throws {
        let text = "foo.bar"
        let range = try #require(provider.completionRange(in: text, cursorLocation: (text as NSString).length))

        #expect(range.location == 0)
        #expect(range.length == 7)
    }

    @Test func completionRangeSafelySkipsEmoji() throws {
        let text = "😀sq"
        let range = try #require(provider.completionRange(in: text, cursorLocation: (text as NSString).length))

        #expect(range.location == 2)
        #expect(range.length == 2)
    }

    @Test func completionRangeAcceptsCombiningMarks() throws {
        let text = "e\u{301}clair"
        let range = try #require(provider.completionRange(in: text, cursorLocation: (text as NSString).length))

        #expect(range.location == 0)
        #expect(range.length == (text as NSString).length)
    }

    @Test func completionRangeReturnsNilInsideSurrogatePair() {
        let text = "😀"

        #expect(provider.completionRange(in: text, cursorLocation: 1) == nil)
    }
}
