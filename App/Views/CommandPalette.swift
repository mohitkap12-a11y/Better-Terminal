import SwiftUI
import BetterTerminalCore

private struct PaletteItem: Identifiable {
    let id = UUID()
    let title: String
    var subtitle: String = ""
    let symbol: String
    let action: () -> Void
}

private enum PaletteTab: String, CaseIterable { case actions = "Actions", commands = "Commands" }

/// ⌘K. Actions tab: your last three commands, then actions, workspaces, layouts and themes.
/// Commands tab (press →): the last 30 commands from every terminal, searchable. ← goes back.
struct CommandPalette: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    /// Closes the palette (it is an overlay, not a sheet, so a click outside can close it too).
    private func dismiss() { model.paletteOpen = false }
    @State private var query = ""
    @State private var selection = 0
    @State private var hits: [AppModel.HistoryHit] = []
    @State private var tab: PaletteTab = .actions
    @FocusState private var focused: Bool

    private func commandItem(_ h: AppModel.HistoryHit, subtitlePrefix: String = "") -> PaletteItem {
        PaletteItem(title: h.entry.command,
                    subtitle: subtitlePrefix + "\(h.workspace) › \(h.tab.title)",
                    symbol: h.entry.failed ? "exclamationmark.circle" : "clock") {
            dismiss(); model.use(h, run: NSEvent.modifierFlags.contains(.command))
        }
    }

    private var items: [PaletteItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if tab == .commands { return hits.map { commandItem($0) } }

        var all: [PaletteItem] = []
        func add(_ t: String, _ sub: String = "", _ sym: String, _ a: @escaping () -> Void) {
            all.append(PaletteItem(title: t, subtitle: sub, symbol: sym, action: { dismiss(); a() }))
        }
        add("New Tab", "⌘T", "plus.square") { model.newTab() }
        add("New Workspace", "⇧⌘N", "rectangle.stack.badge.plus") { model.addWorkspace() }
        add("Split Right", "⌘D", "rectangle.split.2x1") { model.split(.right) }
        add("Split Down", "⇧⌘D", "rectangle.split.1x2") { model.split(.down) }
        add("Keyboard Shortcuts", "⌘/", "keyboard") { model.shortcutsOpen = true }
        add("Find in Terminal", "⌘F", "magnifyingglass") { model.openFind() }
        add(model.active?.broadcast == true ? "Stop Broadcasting Input" : "Broadcast Input to All Panes", "⌥⌘B", "dot.radiowaves.left.and.right") { model.toggleBroadcast() }
        add("Copy Last Command Output", "⌥⌘C", "doc.on.clipboard") { model.copyLastOutput() }
        add("Quick Terminal", "", "chevron.down.square") { QuickTerminal.shared.toggle() }
        add("Save Workspace as Template", "", "square.and.arrow.down") { model.saveTemplate() }
        for t in model.state.templates { add("New Workspace from “\(t.name)”", t.layout.label, "rectangle.stack.badge.plus") { model.newWorkspace(from: t) } }
        add("Show Command History", "⇧⌘H", "clock.arrow.circlepath") { model.toggleHistory() }
        add("Settings", "⌘,", "gearshape") { model.route = .settings }
        add("Show Walkthrough", "", "sparkles") { model.walkthroughOpen = true }
        add("Support Better Terminal", "Sponsor or donate", "heart") { model.route = .settings }
        for (i, ws) in model.state.workspaces.enumerated() {
            add("Switch to \(ws.name)", "⌃⌘\(i + 1)", "rectangle.stack") { model.selectWorkspace(at: i) }
        }
        for l in PaneLayout.presets {
            add("Layout \(l.label)", "rows × columns", "square.grid.2x2") { model.setLayout(l) }
        }
        for t in model.allThemes { add("Theme: \(t.name)", "", "paintpalette") { model.useTheme(t.id) } }
        for m in ThemeMode.allCases { add("Appearance: \(m.rawValue.capitalized)", "", "circle.lefthalf.filled") { model.state.themeMode = m } }

        if !q.isEmpty { return all.filter { $0.title.localizedCaseInsensitiveContains(q) } }
        return all
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.s2) {
                Image(systemName: "command").foregroundStyle(theme.muted)
                TextField(tab == .actions ? "Type an action, or press → for your recent commands" : "Search commands from all terminals",
                          text: $query)
                    .textFieldStyle(.plain).font(.title3).focused($focused)
                    .onSubmit { run(selection) }
                    .onChange(of: query) { selection = 0 }
                    .onChange(of: tab) { selection = 0 }
                    .task(id: "\(tab.rawValue)|\(query)") { await reload() }
                    .onKeyPress(.downArrow) { move(1); return .handled }
                    .onKeyPress(.upArrow) { move(-1); return .handled }
                    .onKeyPress(.rightArrow) { tab = .commands; return .handled }
                    .onKeyPress(.leftArrow) { tab = .actions; return .handled }
                    .onKeyPress(.escape) { dismiss(); return .handled }
            }
            .padding(Metrics.s4)
            HStack(spacing: 6) {
                ForEach(PaletteTab.allCases, id: \.self) { t in
                    Button { tab = t } label: {
                        Text(t.rawValue).font(.system(size: 12, weight: tab == t ? .semibold : .regular))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(tab == t ? theme.selection : Color.clear, in: Capsule())
                            .foregroundStyle(tab == t ? Color.primary : theme.muted)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(tab == .actions ? "→ commands" : "← actions").font(.caption).foregroundStyle(theme.faint)
            }
            .padding(.horizontal, Metrics.s4).padding(.bottom, Metrics.s2)
            Divider()
            if items.isEmpty {
                ContentUnavailableView(tab == .commands ? "No commands yet" : "No matches",
                                       systemImage: tab == .commands ? "clock" : "magnifyingglass")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(Array(items.enumerated()), id: \.element.id) { i, item in
                        HStack(spacing: Metrics.s3) {
                            Image(systemName: item.symbol).frame(width: 20).foregroundStyle(theme.muted)
                            Text(item.title).lineLimit(1).truncationMode(.middle)
                                .font(tab == .commands ? .system(.body, design: .monospaced) : .body)
                            Spacer()
                            Text(item.subtitle).font(.caption).foregroundStyle(theme.faint).lineLimit(1)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .listRowBackground(i == selection ? theme.selection : Color.clear)
                        .onTapGesture { run(i) }
                        .id(i)
                    }
                    .listStyle(.plain)
                    .onChange(of: selection) { proxy.scrollTo(selection) }
                }
            }
            if tab == .commands {
                Divider()
                Text("⏎ puts the command at that tab's prompt · ⌘⏎ runs it")
                    .font(.caption).foregroundStyle(theme.faint).padding(.vertical, 6)
            }
        }
        .frame(width: 600, height: 440)
        .onAppear { focused = true }
    }

    /// Up from the first row goes to the last, down from the last goes to the first.
    private func move(_ delta: Int) {
        let n = items.count
        guard n > 0 else { return }
        selection = (selection + delta + n) % n
    }

    private func reload() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        hits = tab == .commands ? model.searchAllHistory(q, limit: 30) : []
    }

    private func run(_ i: Int) {
        let list = items
        guard list.indices.contains(i) else { return }
        list[i].action()
    }
}
