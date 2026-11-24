import SwiftUI
import BetterTerminalCore

private struct PaletteItem: Identifiable {
    let id = UUID()
    let title: String
    var subtitle: String = ""
    let symbol: String
    let action: () -> Void
}

/// ⌘K: actions, workspaces, layouts, themes and history.
struct CommandPalette: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool

    private var items: [PaletteItem] {
        var all: [PaletteItem] = []
        func add(_ t: String, _ sub: String = "", _ sym: String, _ a: @escaping () -> Void) {
            all.append(PaletteItem(title: t, subtitle: sub, symbol: sym, action: { dismiss(); a() }))
        }
        add("New Tab", "⌘T", "plus.square") { model.newTab() }
        add("New Workspace", "⇧⌘N", "rectangle.stack.badge.plus") { model.addWorkspace() }
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
        for t in Theme.all { add("Theme: \(t.name)", "", "paintpalette") { model.state.themeID = t.id } }
        for m in ThemeMode.allCases { add("Appearance: \(m.rawValue.capitalized)", "", "circle.lefthalf.filled") { model.state.themeMode = m } }

        let q = query.trimmingCharacters(in: .whitespaces)
        var out = q.isEmpty ? all : all.filter { $0.title.localizedCaseInsensitiveContains(q) }
        for e in model.recentHistory().filter({ q.isEmpty || $0.command.localizedCaseInsensitiveContains(q) }).prefix(q.isEmpty ? 5 : 12) {
            out.append(PaletteItem(title: e.command,
                                   subtitle: "history · " + e.cwd.replacingOccurrences(of: NSHomeDirectory(), with: "~"),
                                   symbol: e.failed ? "exclamationmark.circle" : "clock") {
                dismiss(); model.route = .terminal; model.activeSession()?.insert(e.command)
            })
        }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.s2) {
                Image(systemName: "command").foregroundStyle(theme.muted)
                TextField("Type a command or search history", text: $query)
                    .textFieldStyle(.plain).font(.title3).focused($focused)
                    .onSubmit { run(selection) }
                    .onChange(of: query) { selection = 0 }
                    .onKeyPress(.downArrow) { selection = min(selection + 1, max(items.count - 1, 0)); return .handled }
                    .onKeyPress(.upArrow) { selection = max(selection - 1, 0); return .handled }
                    .onKeyPress(.escape) { dismiss(); return .handled }
            }
            .padding(Metrics.s4)
            Divider()
            ScrollViewReader { proxy in
                List(Array(items.enumerated()), id: \.element.id) { i, item in
                    HStack(spacing: Metrics.s3) {
                        Image(systemName: item.symbol).frame(width: 20).foregroundStyle(theme.muted)
                        Text(item.title).lineLimit(1).truncationMode(.middle)
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
        .frame(width: 560, height: 400)
        .onAppear { focused = true }
    }

    private func run(_ i: Int) {
        let list = items
        guard list.indices.contains(i) else { return }
        list[i].action()
    }
}
