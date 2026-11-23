import SwiftUI
import BetterTerminalCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView {
            Form {
                Picker("Appearance", selection: $model.state.themeMode) {
                    Text("System").tag(ThemeMode.system)
                    Text("Light").tag(ThemeMode.light)
                    Text("Dark").tag(ThemeMode.dark)
                }
                .pickerStyle(.segmented)

                Section("Terminal") {
                    Stepper("Font size: \(Int(model.state.terminalFontSize)) pt",
                            value: $model.state.terminalFontSize, in: 9...32, step: 1)
                        .monospacedDigit()
                }

                Section("Color theme") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.s3), count: 3),
                              spacing: Metrics.s3) {
                        ForEach(Theme.all) { t in
                            ThemeSwatch(theme: t, selected: t.id == model.state.themeID)
                                .onTapGesture { model.state.themeID = t.id }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Appearance", systemImage: "paintpalette") }

            Form {
                Section("Data") {
                    LabeledContent("Stored at") {
                        Text(model.store.directory.path).textSelection(.enabled)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Reveal in Finder") { NSWorkspace.shared.open(model.store.directory) }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }
            AISettings()
                .tabItem { Label("AI", systemImage: "sparkles") }
        }
        .frame(width: 520, height: 460)
    }
}

private struct ThemeSwatch: View {
    @Environment(\.colorScheme) private var scheme
    let theme: Theme
    let selected: Bool

    var body: some View {
        VStack(spacing: Metrics.s1) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Metrics.radiusControl).fill(theme.background(scheme))
                VStack(alignment: .leading, spacing: 3) {
                    Capsule().fill(theme.accent).frame(width: 18, height: 4)
                    Capsule().fill(theme.foreground(scheme).opacity(0.7)).frame(width: 40, height: 4)
                    Capsule().fill(theme.foreground(scheme).opacity(0.4)).frame(width: 28, height: 4)
                }
                .padding(Metrics.s2)
            }
            .frame(height: 56)
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.radiusControl)
                    .strokeBorder(selected ? theme.accent : Color.secondary.opacity(0.3), lineWidth: selected ? 2 : 1)
            }
            Text(theme.name).font(.caption)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct AISettings: View {
    @Environment(AppModel.self) private var model
    @State private var key = ""
    @State private var saved = false

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Picker("Provider", selection: $model.state.aiProvider) {
                    Text("Anthropic (Claude)").tag("anthropic")
                    Text("Ollama (local, private)").tag("ollama")
                }
                TextField("Model", text: $model.state.aiModel,
                          prompt: Text(AIClient.defaultModel(for: model.state.aiProvider)))
                if model.state.aiProvider == "anthropic" {
                    SecureField("API key", text: $key, prompt: Text(Keychain.get(account: AIClient.keychainAccount) == nil ? "sk-ant-…" : "Saved in Keychain"))
                    HStack {
                        Button("Save key") { Keychain.set(key, account: AIClient.keychainAccount); key = ""; saved = true }
                            .disabled(key.isEmpty)
                        Button("Remove key", role: .destructive) { Keychain.set("", account: AIClient.keychainAccount); saved = false }
                        if saved { Text("Saved").foregroundStyle(.secondary).font(.caption) }
                    }
                }
            } footer: {
                Text("AI is off until configured. Only the text you type in the palette (or the one failed command you ask about, with its exit code and directory) is sent. Your key stays in the macOS Keychain. Choose Ollama to keep everything on this Mac.")
            }
        }
        .formStyle(.grouped)
    }
}
