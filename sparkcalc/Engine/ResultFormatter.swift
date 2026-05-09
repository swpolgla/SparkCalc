import Foundation

// MARK: - Public Entry Point

/// Evaluates an array of expression lines and returns a result for each.
/// Every input line — including function definition lines and blank lines — has
/// a corresponding entry in the output. Function definition lines and blank/
/// invalid lines return "".
public func EvaluateLines(_ lines: [String]) -> [String] {
    let engine = CalculatorEngine()
    return engine.evaluate(lines: lines)
}

// MARK: - Number Formatting

func formatResult(_ value: Double) -> String {
    if value.isNaN      { return "NaN" }
    if value.isInfinite { return value > 0 ? "∞" : "-∞" }

    if value == value.rounded() && abs(value) < 1e15 {
        return String(format: "%.0f", value)
    }

    var str = String(format: "%.15g", value)
    if str.contains(".") && !str.contains("e") && !str.contains("E") {
        str = str.replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }
    return str
}
