import Foundation
@testable import sparkcalc
import Testing

/// Performance benchmarks for the `CalculatorEngine.evaluate(lines:)`
/// memoization change. Measures cold (cache-miss) cost, cache-hit cost,
/// the per-keystroke pattern (one cold + one hit), and the still-duplicated
/// `components(separatedBy:)` line-split cost as context.
///
/// Runs `.serialized` so microbenchmark timings are not skewed by parallel
/// test execution on the same core.
@Suite(.serialized)
struct PerfBenchmarkTests {
    // MARK: - Synthetic document generation

    /// Builds a synthetic document of `lineCount` lines mixing arithmetic,
    /// variable assignments, references, and builtin calls — representative
    /// of real usage.
    private static func makeDocument(lineCount: Int) -> [String] {
        let pattern: [String] = [
            "1 + 2 * 3 - 4 / 2",
            "x = 42",
            "y = x * 2 + sin(0.5)",
            "sqrt(x^2 + y^2) + max(1, 2, 3, 4)"
        ]
        return (0..<lineCount).map { i in pattern[i % pattern.count] }
    }

    /// Converts a `Duration` to microseconds as a `Double`.
    private static func micros(_ d: Duration) -> Double {
        let (secs, attos) = d.components
        return Double(secs) * 1_000_000.0 + Double(attos) / 1_000_000_000_000.0
    }

    // MARK: - Benchmarks

    @Test(arguments: [100, 500, 1000, 5000])
    func evaluateColdCost(lineCount: Int) {
        let lines = Self.makeDocument(lineCount: lineCount)
        let iterations = 50
        let result = ContinuousClock().measure {
            for _ in 0..<iterations {
                let engine = CalculatorEngine()
                _ = engine.evaluate(lines: lines)
            }
        }
        let perCall = Self.micros(result) / Double(iterations)
        print("[evaluateCold] lines=\(lineCount) -> \(String(format: "%.2f", perCall)) us/call")
    }

    @Test(arguments: [100, 500, 1000, 5000])
    func evaluateCacheHitCost(lineCount: Int) {
        let lines = Self.makeDocument(lineCount: lineCount)
        let engine = CalculatorEngine()
        _ = engine.evaluate(lines: lines)
        let iterations = 10000
        let result = ContinuousClock().measure {
            for _ in 0..<iterations {
                _ = engine.evaluate(lines: lines)
            }
        }
        let perCall = Self.micros(result) / Double(iterations)
        print("[evaluateCacheHit] lines=\(lineCount) -> \(String(format: "%.4f", perCall)) us/call")
    }

    @Test(arguments: [100, 500, 1000, 5000])
    func perKeystrokeMemoized(lineCount: Int) {
        let lines = Self.makeDocument(lineCount: lineCount)
        let iterations = 50
        let result = ContinuousClock().measure {
            for _ in 0..<iterations {
                let engine = CalculatorEngine()
                _ = engine.evaluate(lines: lines)
                _ = engine.evaluate(lines: lines)
            }
        }
        let perCall = Self.micros(result) / Double(iterations)
        print("[perKeystrokeMemoized] lines=\(lineCount) -> \(String(format: "%.2f", perCall)) us/keystroke")
    }

    @Test(arguments: [100, 500, 1000, 5000])
    func lineSplitCost(lineCount: Int) {
        let text = Self.makeDocument(lineCount: lineCount).joined(separator: "\n")
        for _ in 0..<3 {
            _ = text.components(separatedBy: "\n")
        }
        let iterations = 200
        let result = ContinuousClock().measure {
            for _ in 0..<iterations {
                _ = text.components(separatedBy: "\n")
            }
        }
        let perCall = Self.micros(result) / Double(iterations)
        print("[componentsSplit] lines=\(lineCount) -> \(String(format: "%.2f", perCall)) us/call")
    }
}
