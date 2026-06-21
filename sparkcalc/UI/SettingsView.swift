import AppKit
import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @Environment(ThemeSettings.self) var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Toggle("Enable Smart Substitutions", isOn: $settings.smartSubstitutionsEnabled)

                Toggle("Alternating Line Backgrounds", isOn: $settings.alternatingLineBackgroundsEnabled)

                if settings.alternatingLineBackgroundsEnabled {
                    HStack {
                        Text("Tint Intensity")
                        Slider(value: $settings.lineTintIntensity, in: 0...1)
                            .accessibilityLabel("Tint Intensity")
                    }
                }
            }

            Section("Layout") {
                HStack {
                    Text("Default Output Pane Width")
                    Spacer()
                    Text("\(Int(settings.defaultAnswerColumnFraction * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.defaultAnswerColumnFraction, in: 0.1...0.9, step: 0.01)
                    .accessibilityLabel("Default Output Pane Width")
            }

            Section("Syntax Colors") {
                ColorSettingRow(title: "Answer", color: settings.binding(for: \.answer))
                ColorSettingRow(title: "Function Call", color: settings.binding(for: \.functionCall))
                ColorSettingRow(title: "Function Declaration", color: settings.binding(for: \.functionDecl))
                ColorSettingRow(title: "Invalid Call", color: settings.binding(for: \.invalidCall))
                ColorSettingRow(title: "Local Parameter Declaration", color: settings.binding(for: \.localParamDeclaration))
                ColorSettingRow(title: "Local Parameter Use", color: settings.binding(for: \.localParamUse))
                ColorSettingRow(title: "Local Variable Declaration", color: settings.binding(for: \.localVarDeclaration))
                ColorSettingRow(title: "Local Variable Use", color: settings.binding(for: \.localVarUse))
                ColorSettingRow(title: "Numbers", color: settings.binding(for: \.number))
                ColorSettingRow(title: "Operators", color: settings.binding(for: \.operatorColor))
                ColorSettingRow(title: "Plain Text", color: settings.binding(for: \.plainText))
                ColorSettingRow(title: "Variable Declaration", color: settings.binding(for: \.variableDeclaration))
                ColorSettingRow(title: "Variable Use", color: settings.binding(for: \.variableUse))
            }

            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .scenePadding()
        .frame(minWidth: 420, maxWidth: 500)
    }
}

// MARK: - Color Setting Row

struct ColorSettingRow: View {
    let title: String
    @Binding var color: NSColor

    private var selectedPresetName: String? {
        ThemeSettings.presets.first { $0.matches(color) }?.name
    }

    private let customTag = "Custom…"

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Picker("", selection: Binding(
                get: { selectedPresetName ?? customTag },
                set: { newValue in
                    if let preset = ThemeSettings.presets.first(where: { $0.name == newValue }) {
                        color = preset.color
                    }
                }
            )) {
                ForEach(ThemeSettings.presets) { preset in
                    Text(preset.name).tag(preset.name)
                }
                Text(customTag).tag(customTag)
            }
            .labelsHidden()
            .frame(maxWidth: 180)

            if selectedPresetName == nil {
                NSColorWellView(color: $color)
                    .frame(width: 44, height: 23)
            }
        }
    }
}

// MARK: - NSColorWell Wrapper

struct NSColorWellView: NSViewRepresentable {
    @Binding var color: NSColor

    func makeNSView(context: Context) -> NSColorWell {
        let well = NSColorWell()
        well.target = context.coordinator
        well.action = #selector(Coordinator.colorChanged(_:))
        well.color = color
        return well
    }

    func updateNSView(_ nsView: NSColorWell, context _: Context) {
        nsView.color = color
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        let parent: NSColorWellView
        init(_ parent: NSColorWellView) {
            self.parent = parent
        }

        @objc func colorChanged(_ sender: NSColorWell) {
            parent.color = sender.color
        }
    }
}

#Preview {
    SettingsView()
        .environment(ThemeSettings())
}
