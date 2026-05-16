import Testing
import SwiftUI
@testable import sparkcalc

struct ThemeSettingsTests {

    @Test func initialDefaults() {
        let settings = ThemeSettings()
        #expect(settings.theme == .default)
        #expect(settings.alternatingLineBackgroundsEnabled == true)
        #expect(settings.lineTintIntensity == 0.75)
        #expect(settings.defaultAnswerColumnFraction == 0.25)
    }

    @Test func resetToDefaultsRestoresMutatedValues() {
        let settings = ThemeSettings()
        settings.theme.number = .systemRed
        settings.alternatingLineBackgroundsEnabled = false
        settings.lineTintIntensity = 0.5
        settings.defaultAnswerColumnFraction = 0.5
        settings.resetToDefaults()
        #expect(settings.theme == .default)
        #expect(settings.alternatingLineBackgroundsEnabled == true)
        #expect(settings.lineTintIntensity == 0.75)
        #expect(settings.defaultAnswerColumnFraction == 0.25)
    }

    @Test func bindingGetReturnsCurrentValue() {
        let settings = ThemeSettings()
        let binding = settings.binding(for: \.number)
        #expect(binding.wrappedValue == .textColor)
    }

    @Test func bindingSetUpdatesTheme() {
        let settings = ThemeSettings()
        let binding = settings.binding(for: \.number)
        binding.wrappedValue = .systemRed
        #expect(settings.theme.number == .systemRed)
        #expect(settings.theme != .default)
    }

    @Test func presetsIsNonEmpty() {
        #expect(!ThemeSettings.presets.isEmpty)
    }

    @Test func presetColorMatchesItself() {
        let preset = ThemeSettings.presets[0]
        #expect(preset.matches(preset.color))
    }

    @Test func presetColorDoesNotMatchDifferentColor() {
        let preset = ThemeSettings.presets[0]
        let different = ThemeSettings.presets[1]
        #expect(!preset.matches(different.color))
    }
}
