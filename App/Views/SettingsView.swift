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
        }
        .frame(width: 520, height: 420)
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
