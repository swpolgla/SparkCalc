import AppKit

extension NSColor {
    /// Compares two colors within an RGB tolerance.
    func isEqual(to other: NSColor, tolerance: CGFloat = 0.001) -> Bool {
        guard let s1 = usingColorSpace(.sRGB),
              let s2 = other.usingColorSpace(.sRGB)
        else {
            return false
        }
        return abs(s1.redComponent - s2.redComponent) < tolerance &&
            abs(s1.greenComponent - s2.greenComponent) < tolerance &&
            abs(s1.blueComponent - s2.blueComponent) < tolerance &&
            abs(s1.alphaComponent - s2.alphaComponent) < tolerance
    }
}
