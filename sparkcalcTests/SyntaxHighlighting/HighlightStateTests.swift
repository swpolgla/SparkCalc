import Testing
import AppKit
@testable import sparkcalc

struct HighlightStateTests {

    // MARK: - LineKind Equality

    @Test func lineKindFunctionHeaderEquality() {
        #expect(LineKind.functionHeader("f") == .functionHeader("f"))
        #expect(LineKind.functionHeader("f") != .functionHeader("g"))
    }

    @Test func lineKindFunctionBodyEquality() {
        #expect(LineKind.functionBody("f") == .functionBody("f"))
        #expect(LineKind.functionBody("f") != .functionBody("g"))
    }

    @Test func lineKindCrossCaseInequality() {
        #expect(LineKind.functionHeader("f") != .functionBody("f"))
        #expect(LineKind.functionHeader("f") != .functionClose)
        #expect(LineKind.functionHeader("f") != .evaluable)
        #expect(LineKind.functionBody("f") != .functionClose)
        #expect(LineKind.functionBody("f") != .evaluable)
        #expect(LineKind.functionClose != .evaluable)
    }

    // MARK: - HighlightState Construction

    @Test func highlightStateStoresProperties() {
        let state = HighlightState(
            lines: ["a = 1", "b = 2"],
            knownVariablesAfterLine: [["a"], ["a", "b"]],
            lineClassifications: [.evaluable, .evaluable],
            functionNames: []
        )
        #expect(state.lines == ["a = 1", "b = 2"])
        #expect(state.knownVariablesAfterLine.count == 2)
        #expect(state.knownVariablesAfterLine[0] == ["a"])
        #expect(state.knownVariablesAfterLine[1] == ["a", "b"])
        #expect(state.lineClassifications == [.evaluable, .evaluable])
        #expect(state.functionNames.isEmpty)
    }

    @Test func highlightStateWithFunctionClassification() {
        let state = HighlightState(
            lines: ["f(a) {", "  return a", "}", "f(1)"],
            knownVariablesAfterLine: [Set(), Set(), Set(), Set()],
            lineClassifications: [.functionHeader("f"), .functionBody("f"), .functionClose, .evaluable],
            functionNames: ["f"]
        )
        #expect(state.lineClassifications.count == 4)
        #expect(state.lineClassifications[0] == .functionHeader("f"))
        #expect(state.lineClassifications[1] == .functionBody("f"))
        #expect(state.lineClassifications[2] == .functionClose)
        #expect(state.lineClassifications[3] == .evaluable)
        #expect(state.functionNames == ["f"])
    }
}
