import Foundation
import Combine

/// Represents a single isolated calculator sheet.
///
/// Each sheet owns its own `CalculatorEngine` and `SyntaxHighlighter`, guaranteeing
/// full isolation of variables, functions, and evaluation state across sheets.
/// For future persistence, only `id`, `name`, and `inputText` need to be serialized;
/// the engine state can be rebuilt from the saved input.
class Sheet: ObservableObject, Identifiable {
    let id: UUID
    @Published var name: String
    @Published var inputText: String = ""
    @Published var lineHeights: [CGFloat] = [17]

    let engine: CalculatorEngine
    let highlighter: SyntaxHighlighter

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
        let freshEngine = CalculatorEngine()
        self.engine = freshEngine
        self.highlighter = SyntaxHighlighter(engine: freshEngine)
    }
}
