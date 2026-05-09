import AppKit

// MARK: - Syntax Theme

/// Central location for all highlight colors.
///
/// Each property maps a syntactic category to an `NSColor`. Changing a value
/// here immediately affects all subsequent highlighting without restarting the app.
struct SyntaxTheme: Equatable {
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

    static let `default` = SyntaxTheme()
}

extension SyntaxTheme {
    static func == (lhs: SyntaxTheme, rhs: SyntaxTheme) -> Bool {
        lhs.number.isEqual(to: rhs.number) &&
        lhs.variableDeclaration.isEqual(to: rhs.variableDeclaration) &&
        lhs.variableUse.isEqual(to: rhs.variableUse) &&
        lhs.localParamDeclaration.isEqual(to: rhs.localParamDeclaration) &&
        lhs.localParamUse.isEqual(to: rhs.localParamUse) &&
        lhs.localVarDeclaration.isEqual(to: rhs.localVarDeclaration) &&
        lhs.localVarUse.isEqual(to: rhs.localVarUse) &&
        lhs.functionDecl.isEqual(to: rhs.functionDecl) &&
        lhs.functionCall.isEqual(to: rhs.functionCall) &&
        lhs.invalidCall.isEqual(to: rhs.invalidCall) &&
        lhs.operatorColor.isEqual(to: rhs.operatorColor) &&
        lhs.plainText.isEqual(to: rhs.plainText)
    }
}

extension NSColor {
    func isEqual(to other: NSColor, tolerance: CGFloat = 0.001) -> Bool {
        guard let s1 = self.usingColorSpace(.deviceRGB),
              let s2 = other.usingColorSpace(.deviceRGB) else {
            return false
        }
        return abs(s1.redComponent - s2.redComponent) < tolerance &&
               abs(s1.greenComponent - s2.greenComponent) < tolerance &&
               abs(s1.blueComponent - s2.blueComponent) < tolerance &&
               abs(s1.alphaComponent - s2.alphaComponent) < tolerance
    }
}
