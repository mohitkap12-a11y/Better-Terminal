import SwiftUI
import BetterTerminalCore

/// Settings, inside the main window (same layout as MacPeek Remote): sections in one card.
struct SettingsPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "Settings", subtitle: "How Better Terminal looks, updates and what it keeps")
                SectionCard {
                    AppearanceSection()
                    TerminalSection()
                    UpdatesSection()
                    DataSection()
                    ShortcutsSection()
                    AboutSection()
                }
            }
            .frame(maxWidth: 980, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 48)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct AppearanceSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        SettingsSection(title: "Appearance", subtitle: "Light, dark or follow the Mac, and a colour theme", first: true) {
            SettingsRow(title: "Mode", subtitle: "System follows the macOS appearance", showsDivider: false) {
                ChoiceChips(values: ThemeMode.allCases, selection: $model.state.themeMode) { $0.rawValue.capitalized }
            }
            SettingsRow(title: "Colour theme", subtitle: "Soft palettes for the window and the terminal") { EmptyView() }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(Theme.all) { t in
                    ThemeSwatch(theme: t, selected: t.id == model.state.themeID)
                        .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { model.state.themeID = t.id } }
                }
            }
            .padding(.bottom, 8)
        }
    }
}

private struct ThemeSwatch: View {
    @Environment(\.colorScheme) private var scheme
    let theme: Theme
    let selected: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                Rectangle().fill(theme.sidebar).frame(width: 22)
                ZStack(alignment: .topLeading) {
                    theme.terminalBackground(scheme)
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(theme.accent).frame(width: 18, height: 4)
                        Capsule().fill(theme.terminalForeground(scheme).opacity(0.75)).frame(width: 36, height: 4)
                        Capsule().fill(theme.terminalForeground(scheme).opacity(0.4)).frame(width: 24, height: 4)
                    }
                    .padding(8)
                }
            }
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(selected ? theme.accent : Color.primary.opacity(0.12), lineWidth: selected ? 2 : 1)
            }
            Text(theme.name).font(.system(size: 11.5, weight: selected ? .semibold : .regular))
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct TerminalSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        SettingsSection(title: "Terminal", subtitle: "Text size in every pane") {
            SettingsRow(title: "Font size", subtitle: "⌘+ and ⌘− change it too", showsDivider: false) {
                Stepper("\(Int(model.state.terminalFontSize)) pt", value: $model.state.terminalFontSize, in: 9...32, step: 1)
                    .monospacedDigit()
            }
            SettingsRow(title: "Resume on relaunch",
                        subtitle: "Reopen your workspaces and tabs with their text and history. Running programs can't be revived; a fresh shell starts below. The text is stored on this Mac and may contain anything you printed, so turn this off if you handle secrets.") {
                Toggle("", isOn: $model.state.restoreTerminalText).labelsHidden().toggleStyle(.switch)
                    .onChange(of: model.state.restoreTerminalText) { _, on in
                        if !on { model.clearSavedTerminalText() }
                    }
            }
            SettingsRow(title: "Saved terminal text", subtitle: "Delete the text saved for resuming. History is kept.") {
                PillButton(title: "Clear") { model.clearSavedTerminalText() }
            }
        }
    }
}

private struct UpdatesSection: View {
    @EnvironmentObject private var updater: UpdaterService
    @Environment(\.theme) private var theme

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return b.isEmpty || b == v ? v : "\(v) (\(b))"
    }

    var body: some View {
        SettingsSection(title: "Updates", subtitle: "Better Terminal can keep itself up to date") {
            SettingsRow(title: "Version", subtitle: version, showsDivider: false) {
                PillButton(title: "Check for Updates", prominent: true,
                           disabled: !updater.isAvailable || !updater.canCheckForUpdates) { updater.checkForUpdates() }
            }
            if !updater.isAvailable {
                Text("Updates are available in the packaged release. This build was run from Xcode.")
                    .font(.system(size: 11.5)).foregroundStyle(theme.muted).padding(.bottom, 6)
            }
            SettingsRow(title: "Check automatically", subtitle: "Look for a new version about once a day") {
                Toggle("", isOn: $updater.automaticallyChecks).labelsHidden().toggleStyle(.switch)
                    .disabled(!updater.isAvailable)
            }
            SettingsRow(title: "Install automatically", subtitle: "Download and install updates in the background") {
                Toggle("", isOn: $updater.automaticallyDownloads).labelsHidden().toggleStyle(.switch)
                    .disabled(!updater.isAvailable || !updater.automaticallyChecks)
            }
            SettingsRow(title: "Update channel",
                        subtitle: updater.channel == .beta
                            ? "Beta gets new features first and may be less stable. Switching back keeps the installed beta until the next stable release."
                            : "Stable gets tested releases only") {
                ChoiceChips(values: UpdateChannel.allCases, selection: $updater.channel) { $0.title }
                    .disabled(!updater.isAvailable)
            }
        }
    }
}

private struct DataSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        SettingsSection(title: "Data", subtitle: "Workspaces and command history stay on this Mac") {
            SettingsRow(title: "Stored at", subtitle: model.store.directory.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"),
                        showsDivider: false) {
                PillButton(title: "Reveal in Finder") { NSWorkspace.shared.open(model.store.directory) }
            }
        }
    }
}

private struct ShortcutsSection: View {
    @Environment(\.theme) private var theme
    private let items: [(String, String)] = [
        ("New tab", "⌘T"), ("Close tab", "⌘W"), ("New workspace", "⇧⌘N"), ("Switch workspace", "⌃⌘1–9"),
        ("Command palette", "⌘K"), ("Pane layout", "⌥⌘L"), ("Move between panes", "⌘← ↑ ↓ →"), ("Command history", "⇧⌘H"), ("Settings", "⌘,")
    ]

    var body: some View {
        SettingsSection(title: "Shortcuts", subtitle: "Keyboard shortcuts") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                ForEach(items, id: \.0) { item in
                    HStack {
                        Text(item.0).font(.system(size: 12.5))
                        Spacer()
                        Text(item.1).font(.system(size: 11.5, design: .rounded)).foregroundStyle(theme.muted)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(theme.track, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }
}

private struct AboutSection: View {
    @Environment(\.theme) private var theme
    @Environment(AppModel.self) private var model

    var body: some View {
        SettingsSection(title: "About", subtitle: "Open source") {
            HStack(spacing: 12) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon).resizable().frame(width: 44, height: 44)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Better Terminal").font(.system(size: 13, weight: .semibold))
                    Link("github.com/mohitkap12-a11y/Better-Terminal",
                         destination: URL(string: "https://github.com/mohitkap12-a11y/Better-Terminal")!)
                        .font(.system(size: 12)).foregroundStyle(theme.accent)
                }
            }
            .padding(.vertical, 6)
            SettingsRow(title: "Walkthrough", subtitle: "Replay the quick tour") {
                PillButton(title: "Show Walkthrough") { model.route = .terminal; model.walkthroughOpen = true }
            }
        }
    }
}
