import Testing
import AppKit
@testable import sparkcalc

struct SyntaxThemeTests {

    // MARK: - Equality

    @Test func defaultThemesAreEqual() {
        let a = SyntaxTheme.default
        let b = SyntaxTheme()
        #expect(a == b)
        #expect(a == .default)
    }

    @Test func equalCustomThemes() {
        var a = SyntaxTheme()
        a.number = .systemRed
        a.operatorColor = .systemBlue
        var b = SyntaxTheme()
        b.number = .systemRed
        b.operatorColor = .systemBlue
        #expect(a == b)
    }

    // MARK: - Inequality (all 13 color properties)
    // Note: Cannot use @Test(arguments:) with key paths under Swift 6 strict
    // concurrency because WritableKeyPath is not Sendable and SyntaxTheme
    // properties are @MainActor-isolated. Individual assertions are used instead.

    @Test func inequalityAfterChangingEachColor() {
        var theme = SyntaxTheme.default

        theme.number = .systemRed
        #expect(theme != .default); theme = .default

        theme.operatorColor = .systemRed
        #expect(theme != .default); theme = .default

        theme.variableDeclaration = .systemRed
        #expect(theme != .default); theme = .default

        theme.variableUse = .systemRed
        #expect(theme != .default); theme = .default

        theme.localParamDeclaration = .systemRed
        #expect(theme != .default); theme = .default

        theme.localParamUse = .systemRed
        #expect(theme != .default); theme = .default

        theme.localVarDeclaration = .systemRed
        #expect(theme != .default); theme = .default

        theme.localVarUse = .systemRed
        #expect(theme != .default); theme = .default

        theme.functionDecl = .systemRed
        #expect(theme != .default); theme = .default

        theme.functionCall = .systemRed
        #expect(theme != .default); theme = .default

        theme.invalidCall = .systemBlue
        #expect(theme != .default); theme = .default

        theme.plainText = .systemRed
        #expect(theme != .default); theme = .default

        theme.answer = .systemRed
        #expect(theme != .default)
    }
}
