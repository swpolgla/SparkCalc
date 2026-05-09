// MARK: - Highlight State (for incremental optimization)

enum LineKind: Equatable {
    case functionHeader(String)   // associated value is function name
    case functionBody(String)     // associated value is owning function name
    case functionClose
    case evaluable
}

struct HighlightState {
    let lines: [String]
    let knownVariablesAfterLine: [Set<String>]
    let lineClassifications: [LineKind]
    let functionNames: Set<String>
}
