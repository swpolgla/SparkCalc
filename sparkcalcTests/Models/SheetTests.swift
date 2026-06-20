import Foundation
import Testing
@testable import sparkcalc

struct SheetTests {

    // MARK: - Initialization

    @Test func initialDefaults() {
        let sheet = Sheet(name: "Test")
        #expect(sheet.name == "Test")
        #expect(sheet.inputText == "")
        #expect(sheet.answers.isEmpty)
        #expect(sheet.lineHeights == [Sheet.defaultLineHeight])
    }

    @Test func initPreservesCustomId() {
        let id = UUID()
        let sheet = Sheet(id: id, name: "Custom")
        #expect(sheet.id == id)
    }

    @Test func answerColumnFractionDefault() {
        let sheet = Sheet(name: "Test")
        #expect(sheet.answerColumnFraction == 0.25)
    }

    @Test func defaultLineHeightIs17() {
        #expect(Sheet.defaultLineHeight == 17)
    }

    // MARK: - updateAnswers

    @Test func updateAnswersEvaluatesExpressions() {
        let sheet = Sheet(name: "Math")
        sheet.inputText = "1 + 1\n2 * 3"
        sheet.updateAnswers()
        #expect(sheet.answers == ["2", "6"])
    }

    @Test func updateAnswersWithTrailingNewline() {
        let sheet = Sheet(name: "Trailing")
        sheet.inputText = "1 + 1\n"
        sheet.updateAnswers()
        #expect(sheet.answers == ["2", ""])
    }

    @Test func updateAnswersWithEmptyInput() {
        let sheet = Sheet(name: "Empty")
        sheet.updateAnswers()
        #expect(sheet.answers == [""])
    }

    @Test func updateAnswersWithVariables() {
        let sheet = Sheet(name: "Vars")
        sheet.inputText = "a = 5\na * 2"
        sheet.updateAnswers()
        #expect(sheet.answers == ["5", "10"])
    }

    @Test func updateAnswersWithFunctionDefinition() {
        let sheet = Sheet(name: "Func")
        sheet.inputText = "f(a, b) {\n  return a + b\n}\nf(1, 2)"
        sheet.updateAnswers()
        #expect(sheet.answers.count == 4)
        #expect(sheet.answers[0] == "")  // function header
        #expect(sheet.answers[1] == "")  // function body
        #expect(sheet.answers[2] == "")  // function close
        #expect(sheet.answers[3] == "3") // function call
    }

    @Test func updateAnswersWithInvalidExpression() {
        let sheet = Sheet(name: "Error")
        sheet.inputText = "1 + * 2"
        sheet.updateAnswers()
        #expect(sheet.answers == [""])
    }

    // MARK: - lineHeights

    @Test func lineHeightsMutation() {
        let sheet = Sheet(name: "Resize")
        sheet.lineHeights = [20, 30, 40]
        #expect(sheet.lineHeights == [20, 30, 40])
    }

    // MARK: - Isolation

    @Test func sheetsHaveIndependentEngines() {
        let sheetA = Sheet(name: "A")
        let sheetB = Sheet(name: "B")
        #expect(sheetA.engine !== sheetB.engine)
    }

    @Test func sheetsHaveIndependentUndoManagers() {
        let sheetA = Sheet(name: "A")
        let sheetB = Sheet(name: "B")
        #expect(sheetA.undoManager !== sheetB.undoManager)
    }

    @Test func highlighterSharesSheetEngine() {
        let sheet = Sheet(name: "A")
        #expect(sheet.highlighter.engine === sheet.engine)
    }

    @Test func variablesDoNotLeakAcrossSheets() {
        let sheetA = Sheet(name: "A")
        sheetA.inputText = "x = 10\nx"
        sheetA.updateAnswers()
        #expect(sheetA.answers == ["10", "10"])

        let sheetB = Sheet(name: "B")
        sheetB.inputText = "x"
        sheetB.updateAnswers()
        #expect(sheetB.answers == [""])
    }
}
