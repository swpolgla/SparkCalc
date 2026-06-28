import Foundation

struct AutocompleteProvider {
    private struct CompletionContext {
        let prefix: String
        let range: NSRange
        let lineIndex: Int
    }

    private let tokenizer = Tokenizer()

    private static let builtInFunctionSignatures: [String: String] = [
        "abs": "abs(value)",
        "acos": "acos(value)",
        "asin": "asin(value)",
        "atan": "atan(value)",
        "atan2": "atan2(y, x)",
        "cbrt": "cbrt(value)",
        "ceil": "ceil(value)",
        "cos": "cos(value)",
        "exp": "exp(value)",
        "floor": "floor(value)",
        "hypot": "hypot(x, y)",
        "log": "log(value)",
        "log10": "log10(value)",
        "log2": "log2(value)",
        "max": "max(value, ...)",
        "min": "min(value, ...)",
        "pow": "pow(base, exponent)",
        "round": "round(value)",
        "sin": "sin(value)",
        "sqrt": "sqrt(value)",
        "tan": "tan(value)"
    ]

    func suggestions(in text: String, cursorLocation: Int, engine: CalculatorEngine, minimumPrefixLength: Int) -> [AutocompleteSuggestion] {
        guard let context = completionContext(in: text, cursorLocation: cursorLocation),
              context.prefix.utf16.count >= minimumPrefixLength
        else { return [] }

        let symbols = collectSymbols(beforeLine: context.lineIndex, in: text, engine: engine)
        return rankedSuggestions(symbols: symbols, prefix: context.prefix)
    }

    func completionRange(in text: String, cursorLocation: Int) -> NSRange? {
        completionContext(in: text, cursorLocation: cursorLocation)?.range
    }

    private func completionContext(in text: String, cursorLocation: Int) -> CompletionContext? {
        let nsText = text as NSString
        guard cursorLocation >= 0,
              cursorLocation <= nsText.length
        else { return nil }

        let utf16Cursor = text.utf16.index(text.utf16.startIndex, offsetBy: cursorLocation)
        guard let cursorIndex = String.Index(utf16Cursor, within: text) else { return nil }

        var startIndex = cursorIndex
        while startIndex > text.startIndex {
            let previousIndex = text.unicodeScalars.index(before: startIndex)
            guard isIdentifierContinuation(text.unicodeScalars[previousIndex]) else { break }
            startIndex = previousIndex
        }

        guard startIndex < cursorIndex,
              isIdentifierStart(text.unicodeScalars[startIndex])
        else { return nil }

        let startLocation = startIndex.utf16Offset(in: text)
        let prefixRange = NSRange(location: startLocation, length: cursorLocation - startLocation)
        let prefix = String(text[startIndex..<cursorIndex])
        let lineIndex = text[..<startIndex].filter { $0 == "\n" }.count
        return CompletionContext(prefix: prefix, range: prefixRange, lineIndex: lineIndex)
    }

    private func collectSymbols(beforeLine cursorLine: Int, in text: String, engine: CalculatorEngine) -> [AutocompleteSuggestion] {
        var byName: [String: AutocompleteSuggestion] = [:]

        for name in CalculatorEngine.builtInConstants {
            byName[name] = AutocompleteSuggestion(name: name, detailText: "Built-In Constant", kind: .builtInConstant)
        }

        for name in CalculatorEngine.builtInFunctions {
            let signature = Self.builtInFunctionSignatures[name] ?? "\(name)()"
            byName[name] = AutocompleteSuggestion(
                name: name,
                insertionText: signature,
                displayText: signature,
                detailText: "Built-In Function",
                kind: .builtInFunction
            )
        }

        let lines = Array(text.components(separatedBy: "\n").prefix(max(0, cursorLine)))
        var lineIndex = 0
        while lineIndex < lines.count {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let header = engine.tryParseFunctionHeader(trimmed) {
                let signature = "\(header.name)(\(header.parameters.joined(separator: ", ")))"
                byName[header.name] = AutocompleteSuggestion(
                    name: header.name,
                    insertionText: signature,
                    displayText: signature,
                    detailText: "Function",
                    kind: .function
                )
                lineIndex += 1
                while lineIndex < lines.count {
                    let bodyLine = lines[lineIndex].trimmingCharacters(in: .whitespaces)
                    lineIndex += 1
                    if bodyLine == "}" {
                        break
                    }
                }
                continue
            }

            if let assignRange = engine.findTopLevelAssignment(in: line) {
                let variable = String(line[line.startIndex..<assignRange]).trimmingCharacters(in: .whitespaces)
                if tokenizer.isValidIdentifier(variable) {
                    byName[variable] = AutocompleteSuggestion(name: variable, detailText: "Variable", kind: .variable)
                }
            }
            lineIndex += 1
        }

        return Array(byName.values)
    }

    private func rankedSuggestions(symbols: [AutocompleteSuggestion], prefix: String) -> [AutocompleteSuggestion] {
        let lowerPrefix = prefix.lowercased()
        return symbols
            .filter { $0.name.lowercased().hasPrefix(lowerPrefix) && $0.name != prefix }
            .sorted { lhs, rhs in
                let lhsCaseMatch = lhs.name.hasPrefix(prefix)
                let rhsCaseMatch = rhs.name.hasPrefix(prefix)
                if lhsCaseMatch != rhsCaseMatch { return lhsCaseMatch }

                let lhsUserDefined = lhs.kind == .variable || lhs.kind == .function
                let rhsUserDefined = rhs.kind == .variable || rhs.kind == .function
                if lhsUserDefined != rhsUserDefined { return lhsUserDefined }

                if lhs.name.count != rhs.name.count { return lhs.name.count < rhs.name.count }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private func isIdentifierStart(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "_" || CharacterSet.letters.contains(scalar)
    }

    private func isIdentifierContinuation(_ scalar: Unicode.Scalar) -> Bool {
        isIdentifierStart(scalar) ||
            scalar == "." ||
            CharacterSet.decimalDigits.contains(scalar) ||
            CharacterSet.nonBaseCharacters.contains(scalar)
    }
}
