import Testing
import AppKit
@testable import sparkcalc

struct SyntaxThemeTests {

    @Test func defaultThemesAreEqual() {
        let a = SyntaxTheme.default
        let b = SyntaxTheme()
        #expect(a == b)
        #expect(a == .default)
    }

    @Test func modifiedThemeIsNotEqualToDefault() {
        var theme = SyntaxTheme.default
        theme.number = .systemRed
        #expect(theme != .default)
    }

    @Test func inequalityAfterChangingVariableDeclaration() {
        var theme = SyntaxTheme.default
        theme.variableDeclaration = .systemGreen
        #expect(theme != .default)
    }

    @Test func inequalityAfterChangingFunctionDecl() {
        var theme = SyntaxTheme.default
        theme.functionDecl = .systemOrange
        #expect(theme != .default)
    }

    @Test func inequalityAfterChangingAnswerColor() {
        var theme = SyntaxTheme.default
        theme.answer = .systemRed
        #expect(theme != .default)
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
}
