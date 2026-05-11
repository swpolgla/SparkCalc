import Foundation
import Observation

/// Represents a single isolated calculator sheet.
///
/// Each sheet owns its own `CalculatorEngine` and `SyntaxHighlighter`, guaranteeing
/// full isolation of variables, functions, and evaluation state across sheets.
/// For future persistence, only `id`, `name`, and `inputText` need to be serialized;
/// the engine state can be rebuilt from the saved input.
@Observable
class Sheet: Identifiable {
    let id: UUID
    var name: String
    var inputText: String = ""
    var lineHeights: [CGFloat] = [Sheet.defaultLineHeight]
    var answers: [String] = []

    let engine: CalculatorEngine
    let highlighter: SyntaxHighlighter

    /// Per-sheet undo manager. Provides isolated undo/redo history so that
    /// each sheet's text editor operates independently from the window's
    /// shared undo stack.
    let undoManager = UndoManager()

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
        let freshEngine = CalculatorEngine()
        self.engine = freshEngine
        self.highlighter = SyntaxHighlighter(engine: freshEngine)
    }

    /// Evaluates the current input text and publishes the results.
    func updateAnswers() {
        answers = engine.evaluate(lines: inputText.components(separatedBy: "\n"))
    }

    static let defaultLineHeight: CGFloat = 17
}
