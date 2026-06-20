import SwiftUI
import Observation
import AppKit

/// Observable settings object that owns the live syntax theme.
///
/// Colors are held in memory only (no persistence). Changing the `theme`
/// property notifies observers so highlighters can refresh.
@Observable
class ThemeSettings {
    var theme: SyntaxTheme = .default
    var alternatingLineBackgroundsEnabled: Bool = true
    var lineTintIntensity: Double = 0.75
    var defaultAnswerColumnFraction: CGFloat = 0.25
    var smartSubstitutionsEnabled: Bool = false

    static let presets: [PresetColor] = [
        PresetColor(name: "Label", color: .labelColor),
        PresetColor(name: "Secondary Label", color: .secondaryLabelColor),
        PresetColor(name: "Text", color: .textColor),
        PresetColor(name: "Placeholder Text", color: .placeholderTextColor),
        PresetColor(name: "Separator", color: .separatorColor),
        PresetColor(name: "Red", color: .systemRed),
        PresetColor(name: "Orange", color: .systemOrange),
        PresetColor(name: "Yellow", color: .systemYellow),
        PresetColor(name: "Green", color: .systemGreen),
        PresetColor(name: "Mint", color: .systemMint),
        PresetColor(name: "Teal", color: .systemTeal),
        PresetColor(name: "Cyan", color: .systemCyan),
        PresetColor(name: "Blue", color: .systemBlue),
        PresetColor(name: "Indigo", color: .systemIndigo),
        PresetColor(name: "Purple", color: .systemPurple),
        PresetColor(name: "Pink", color: .systemPink),
        PresetColor(name: "Brown", color: .systemBrown),
    ]

    struct PresetColor: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let color: NSColor

        func matches(_ other: NSColor) -> Bool {
            color.isEqual(to: other)
        }
    }

    func resetToDefaults() {
        let defaults = ThemeSettings()
        theme = defaults.theme
        alternatingLineBackgroundsEnabled = defaults.alternatingLineBackgroundsEnabled
        lineTintIntensity = defaults.lineTintIntensity
        defaultAnswerColumnFraction = defaults.defaultAnswerColumnFraction
        smartSubstitutionsEnabled = defaults.smartSubstitutionsEnabled
    }

    /// Creates a `Binding<NSColor>` for a specific property of the current theme.
    func binding(for keyPath: WritableKeyPath<SyntaxTheme, NSColor>) -> Binding<NSColor> {
        Binding(
            get: { self.theme[keyPath: keyPath] },
            set: { newValue in
                var updated = self.theme
                updated[keyPath: keyPath] = newValue
                self.theme = updated
            }
        )
    }
}
