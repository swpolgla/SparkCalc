import AppKit

// MARK: - Syntax Theme

/// Central location for all highlight colors.
///
/// Each property maps a syntactic category to an `NSColor`. Changing a value
/// here immediately affects all subsequent highlighting without restarting the app.
struct SyntaxTheme {
    var number: NSColor              = .textColor           // numeric literals
    var variableDeclaration: NSColor = .systemBlue          // left side of "=" in top-level assignments
    var variableUse: NSColor         = .systemCyan          // subsequent uses of variables & built-in constants
    var localParamDeclaration: NSColor = .systemTeal        // parameter names in function header
    var localParamUse: NSColor       = .systemMint          // parameter uses inside function body
    var localVarDeclaration: NSColor = .systemTeal          // left side of "=" inside function body
    var localVarUse: NSColor         = .systemMint          // subsequent uses of local vars inside function body
    var functionDecl: NSColor        = .systemPurple.shadow(withLevel: 0.2)!        // function name in declaration header
    var functionCall: NSColor        = .systemPurple        // valid function calls
    var invalidCall: NSColor         = .systemRed           // unknown function calls
    var operatorColor: NSColor       = .secondaryLabelColor // +, -, *, /, ^, %, =
    var plainText: NSColor           = .textColor           // everything else
}
