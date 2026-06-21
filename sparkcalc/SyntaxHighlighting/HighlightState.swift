// MARK: - Highlight State (for incremental optimization)

/// Categorizes each line of the sheet for syntax highlighting purposes.
///
/// The highlighter uses this classification to decide which coloring rules apply.
/// `functionHeader` and `functionBody` carry the owning function's name so that
/// parameter and local-variable scoping can be resolved.
enum LineKind: Equatable {
    case functionHeader(String) // associated value is function name
    case functionBody(String) // associated value is owning function name
    case functionClose
    case evaluable
}

/// Snapshot of the document state used to enable incremental re-highlighting.
///
/// On each edit, the highlighter compares a new `HighlightState` against the
/// previous one to find the first dirty line. If the document structure and
/// variable state upstream of that line are unchanged, only the suffix is
/// re-colored. This avoids O(n) work on every keystroke for large sheets.
struct HighlightState {
    let lines: [String]
    let knownVariablesAfterLine: [Set<String>]
    let lineClassifications: [LineKind]
    let functionNames: Set<String>
}
