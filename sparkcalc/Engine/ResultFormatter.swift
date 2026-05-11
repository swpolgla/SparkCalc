import Foundation

// MARK: - Public Entry Point

/// Evaluates an array of expression lines and returns a formatted result for each.
///
/// Every input line — including function definition lines and blank lines — has a
/// corresponding entry in the output. Function definition lines and blank/invalid
/// lines return an empty string. This is a convenience wrapper that creates a fresh
/// `CalculatorEngine` for one-shot evaluation.
public func evaluateLines(_ lines: [String]) -> [String] {
    let engine = CalculatorEngine()
    return engine.evaluate(lines: lines)
}

// MARK: - Number Formatting

/// Formats a `Double` result for display in the answer column.
///
/// - Integers within `1e15` are shown without a decimal point.
/// - Very large or very small numbers use `%.15g` for compact scientific notation.
/// - Trailing zeros after a decimal point are stripped.
/// - Special values (`NaN`, `±∞`) are rendered as human-readable symbols.
private let integerDisplayThreshold = 1e15
private let numberFormat = "%.15g"
private let trailingZeroPattern = #"\.?0+$"#

func formatResult(_ value: Double) -> String {
    if value.isNaN      { return "NaN" }
    if value.isInfinite { return value > 0 ? "∞" : "-∞" }

    if value == value.rounded() && abs(value) < integerDisplayThreshold {
        return String(format: "%.0f", value)
    }

    var str = String(format: numberFormat, value)
    if str.contains(".") && !str.contains("e") && !str.contains("E") {
        str = str.replacingOccurrences(of: trailingZeroPattern, with: "", options: .regularExpression)
    }
    return str
}
