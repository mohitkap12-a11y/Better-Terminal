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
                    TemplatesSection()
                    UpdatesSection()
                    DataSection()
                    SupportSection()
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

    private func runImport() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Choose colour scheme files (.itermcolors, Ghostty or kitty theme text)"
        guard panel.runModal() == .OK else { return }
        model.importThemes(panel.urls)
    }

    var body: some View {
        @Bindable var model = model
        SettingsSection(title: "Appearance", subtitle: "Light, dark or follow the Mac, and a colour theme", first: true) {
            SettingsRow(title: "Mode",
                        subtitle: model.activeCustomTheme.map { "\($0.name) is a \($0.isDark ? "dark" : "light") theme, so the window stays \($0.isDark ? "dark" : "light"). Pick a built-in theme to use System, Light or Dark." }
                            ?? "System follows the macOS appearance",
                        showsDivider: false) {
                ChoiceChips(values: ThemeMode.allCases, selection: $model.state.themeMode) { $0.rawValue.capitalized }
                    .disabled(model.activeCustomTheme != nil)
                    .opacity(model.activeCustomTheme != nil ? 0.45 : 1)
            }
            SettingsRow(title: "Colour theme", subtitle: "Soft palettes for the window and the terminal") { EmptyView() }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(model.allThemes) { t in
                    ThemeSwatch(theme: t, selected: t.id == model.state.themeID)
                        .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { model.useTheme(t.id) } }
                        .contextMenu {
                            if t.id.hasPrefix("custom-") {
                                Button("Remove Theme", role: .destructive) { model.deleteCustomTheme(String(t.id.dropFirst(7))) }
                            }
                        }
                }
            }
            .padding(.bottom, 8)
            SettingsRow(title: "Import a theme",
                        subtitle: "iTerm2 colour presets (.itermcolors) and Ghostty or kitty theme files. Right-click an imported theme to remove it.",
                        showsDivider: false) {
                PillButton(title: "Import…") { runImport() }
            }
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

private let monospacedFamilies: [String] = {
    let fm = NSFontManager.shared
    return fm.availableFontFamilies.filter { family in
        guard let m = fm.availableMembers(ofFontFamily: family)?.first, let name = m[0] as? String,
              let f = NSFont(name: name, size: 12) else { return false }
        return f.isFixedPitch
    }.sorted()
}()

private struct TerminalSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        SettingsSection(title: "Terminal", subtitle: "Text size in every pane") {
            SettingsRow(title: "Font size", subtitle: "⌘+ and ⌘− change it too", showsDivider: false) {
                Stepper("\(Int(model.state.terminalFontSize)) pt", value: $model.state.terminalFontSize, in: 9...32, step: 1)
                    .monospacedDigit()
            }
            SettingsRow(title: "Font",
                        subtitle: "Any monospaced font installed on this Mac. Ligatures are not supported by the terminal engine yet.") {
                Picker("", selection: $model.state.terminalFontFamily) {
                    Text("System Mono").tag("")
                    ForEach(monospacedFamilies, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden().frame(width: 200)
            }
            SettingsRow(title: "Notify when long commands finish",
                        subtitle: "A notification when a command that ran 10 seconds or more finishes in a tab you are not looking at.") {
                Toggle("", isOn: Binding(get: { model.state.notifyLongCommands }, set: { model.setNotifyLongCommands($0) }))
                    .labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(title: "Quick terminal",
                        subtitle: "A key you press anywhere to drop a terminal down from the top of the screen. Press it again to hide.") {
                Toggle("", isOn: Binding(get: { model.state.quickTerminalEnabled }, set: { model.setQuickTerminal($0) }))
                    .labelsHidden().toggleStyle(.switch)
            }
            if model.state.quickTerminalEnabled {
                SettingsRow(title: "Quick terminal key",
                            subtitle: model.quickStatus.isEmpty ? "Choose the key that opens it." : model.quickStatus) {
                    HStack(spacing: 8) {
                        Picker("", selection: Binding(get: { model.state.quickTerminalHotkey }, set: { model.setQuickHotkey($0) })) {
                            ForEach(QuickHotkey.allCases) { Text($0.label).tag($0.rawValue) }
                        }
                        .labelsHidden().frame(width: 190)
                        PillButton(title: "Show now") { QuickTerminal.shared.toggle() }
                    }
                }
            }
            SettingsRow(title: "Right-click copies selected text",
                        subtitle: "Off: right-click always shows the menu (copy, paste, find, split…). On: with text selected it copies immediately.") {
                Toggle("", isOn: $model.state.rightClickCopies).labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(title: "Resume on relaunch",
                        subtitle: "Reopen your workspaces and tabs with their text and history. Running programs can't be revived; a fresh shell starts below. The text is stored on this Mac and may contain anything you printed, so turn this off if you handle secrets.") {
                Toggle("", isOn: $model.state.restoreTerminalText).labelsHidden().toggleStyle(.switch)
                    .onChange(of: model.state.restoreTerminalText) { _, on in
                        if !on { model.clearSavedTerminalText() }
                    }
            }
            SettingsRow(title: "Confirm before closing a busy tab",
                        subtitle: "Ask first when a command is still running in the tab you close.") {
                Toggle("", isOn: $model.state.confirmCloseRunning).labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(title: "Saved terminal text", subtitle: "Delete the text saved for resuming. History is kept.") {
                PillButton(title: "Clear") { model.clearSavedTerminalText() }
            }
        }
    }
}

private struct TemplatesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var editing: WorkspaceTemplate?

    var body: some View {
        SettingsSection(title: "Workspace templates", subtitle: "Open a whole setup in one click: layout, folders, startup commands") {
            if model.state.templates.isEmpty {
                Text("No templates yet. Right-click a workspace in the sidebar and choose Save as Template, or save the current one here.")
                    .font(.system(size: 12.5)).foregroundStyle(theme.muted).fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 10)
            }
            ForEach(model.state.templates) { t in
                SettingsRow(title: t.name, subtitle: "\(t.layout.label) · \(t.tabs.count) tab\(t.tabs.count == 1 ? "" : "s")") {
                    HStack(spacing: 8) {
                        PillButton(title: "Open") { model.newWorkspace(from: t) }
                        PillButton(title: "Edit") { editing = t }
                        PillButton(title: "Delete") { model.deleteTemplate(t.id) }
                    }
                }
            }
            SettingsRow(title: "Save current workspace", subtitle: "Captures its layout and each tab's folder.", showsDivider: false) {
                PillButton(title: "Save as Template") { model.saveTemplate() }
            }
        }
        .sheet(item: $editing) { t in TemplateEditor(template: t) }
    }
}

private struct TemplateEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var template: WorkspaceTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit template").font(.headline)
            HStack {
                TextField("Name", text: $template.name)
                Picker("Layout", selection: $template.layout) {
                    ForEach(PaneLayout.presets) { Text($0.label).tag($0) }
                }
                .frame(width: 150)
            }
            Text("Tabs").font(.subheadline).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach($template.tabs) { $tab in
                        HStack {
                            TextField("Title", text: $tab.title).frame(width: 110)
                            TextField("Folder", text: $tab.cwd)
                            TextField("Startup command (optional)", text: $tab.command)
                            Button { template.tabs.removeAll { $0.id == tab.id } } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless).accessibilityLabel("Remove tab")
                        }
                    }
                }
            }
            .frame(minHeight: 120, maxHeight: 260)
            HStack {
                Button("Add Tab") { template.tabs.append(.init()) }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    if let i = model.state.templates.firstIndex(where: { $0.id == template.id }) { model.state.templates[i] = template }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(template.name.trimmingCharacters(in: .whitespaces).isEmpty || template.tabs.isEmpty)
            }
        }
        .padding(20).frame(width: 640)
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
    private let groups: [(String, [(String, String)])] = [
        ("Tabs and workspaces", [
            ("New tab", "⌘T"), ("Close tab", "⌘W"), ("New workspace", "⇧⌘N"), ("Switch workspace", "⌃⌘1–9"),
            ("Close tab with middle-click", "middle-click"), ("Rename tab", "double-click")]),
        ("Panes", [
            ("Split right", "⌘D"), ("Split down", "⇧⌘D"), ("Move between panes", "⌘← ↑ ↓ →"),
            ("Pane layout", "⌥⌘L"), ("Broadcast typing to all panes", "⌥⌘I"), ("Swap two panes", "drag header")]),
        ("Search and history", [
            ("Command palette", "⌘K"), ("Palette: Actions ⇄ Commands", "← →"), ("Command history (this tab)", "⇧⌘H"),
            ("Find in terminal", "⌘F"), ("Find next / previous", "⌘G / ⇧⌘G")]),
        ("Terminal", [
            ("Copy last command output", "⌥⌘C"), ("Bigger / smaller text", "⌘+ / ⌘−"),
            ("Quick terminal", "⌃` (changeable)"), ("Open a link", "click or ⌘-click"), ("Settings", "⌘,")])
    ]

    var body: some View {
        SettingsSection(title: "Shortcuts", subtitle: "Keyboard and mouse shortcuts") {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(groups, id: \.0) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.0.uppercased()).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(theme.faint)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                            ForEach(group.1, id: \.0) { item in
                                HStack {
                                    Text(item.0).font(.system(size: 12.5))
                                    Spacer()
                                    Text(item.1).font(.system(size: 11.5, design: .rounded)).foregroundStyle(theme.muted)
                                        .padding(.horizontal, 7).padding(.vertical, 2)
                                        .background(theme.track, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                                }
                            }
                        }
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
            SettingsRow(title: "Diagnostics", subtitle: "A small log file (never your commands or terminal text) that helps when reporting a bug.") {
                PillButton(title: "Open Logs Folder") { Diagnostics.revealLogs() }
            }
            SettingsRow(title: "Walkthrough", subtitle: "Replay the quick tour") {
                PillButton(title: "Show Walkthrough") { model.route = .terminal; model.walkthroughOpen = true }
            }
        }
    }
}

/// Where to send people who want to support Better Terminal. Keep in sync with `site/support.html`.
enum SupportLinks {
    static let github = URL(string: "https://github.com/mohitkap12-a11y/Better-Terminal")!
    static let sponsorGithub = URL(string: "https://github.com/sponsors/mohitkap12-a11y")!
    static let sponsorPaypal = URL(string: "https://paypal.me/mkapoor91")!
    static let issues = URL(string: "https://github.com/mohitkap12-a11y/Better-Terminal/issues/new")!
    static let website = URL(string: "https://mohitkap12-a11y.github.io/Better-Terminal/support.html")!
}

/// A gentle, optional ask: Better Terminal is free and open source, and nothing is gated behind it.
private struct SupportSection: View {
    @Environment(\.theme) private var theme

    var body: some View {
        SettingsSection(title: "Support", subtitle: "Optional. Better Terminal is free and open source") {
            Text("If it saves you time, you can help keep it maintained and growing. Nothing in the app depends on it.")
                .font(.system(size: 12.5)).foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true).padding(.vertical, 10)
            SupportLinkRow(symbol: "heart.fill", title: "Sponsor on GitHub",
                           detail: "Recurring or one-time support through GitHub Sponsors.", url: SupportLinks.sponsorGithub)
            SupportLinkRow(symbol: "creditcard", title: "Donate with PayPal",
                           detail: "A one-time contribution of any amount.", url: SupportLinks.sponsorPaypal)
            SupportLinkRow(symbol: "star", title: "Star on GitHub",
                           detail: "A star helps other people find the app.", url: SupportLinks.github)
            SupportLinkRow(symbol: "exclamationmark.bubble", title: "Report an issue",
                           detail: "Found a bug or want a feature? Open an issue.", url: SupportLinks.issues)
        }
    }
}

private struct SupportLinkRow: View {
    @Environment(\.theme) private var theme
    let symbol: String
    let title: String
    let detail: String
    let url: URL
    @State private var hovering = false

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(theme.accent).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.primary)
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(theme.muted)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(theme.faint)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(hovering ? theme.hover : theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(theme.border))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .padding(.bottom, 6)
        .accessibilityLabel("\(title). \(detail)")
    }
}
