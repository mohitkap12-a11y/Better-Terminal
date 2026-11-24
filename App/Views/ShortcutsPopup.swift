import SwiftUI

/// Every shortcut in one place: used by the popup (⌘/) and by Settings.
enum ShortcutCatalog {
    static let groups: [(title: String, items: [(name: String, keys: String)])] = [
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
            ("Quick terminal", "⌃` (changeable)"), ("Open a link", "click or ⌘-click"),
            ("Keyboard shortcuts", "⌘/"), ("Settings", "⌘,")])
    ]
}

private struct KeyCap: View {
    @Environment(\.theme) private var theme
    let keys: String
    var body: some View {
        Text(keys).font(.system(size: 11.5, design: .rounded)).foregroundStyle(theme.muted)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(theme.track, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// A quick look at all shortcuts, in a popup like the search palette. Type to filter, esc to close.
struct ShortcutsPopup: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var focused: Bool

    private var filtered: [(title: String, items: [(name: String, keys: String)])] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return ShortcutCatalog.groups }
        return ShortcutCatalog.groups.compactMap { g in
            let hits = g.items.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.keys.localizedCaseInsensitiveContains(q) }
            return hits.isEmpty ? nil : (g.title, hits)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.s2) {
                Image(systemName: "keyboard").foregroundStyle(theme.muted)
                TextField("Search shortcuts", text: $query)
                    .textFieldStyle(.plain).font(.title3).focused($focused)
                    .onKeyPress(.escape) { dismiss(); return .handled }
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(theme.faint) }
                    .buttonStyle(.plain).accessibilityLabel("Close")
            }
            .padding(Metrics.s4)
            Divider()
            if filtered.isEmpty {
                ContentUnavailableView("No matching shortcuts", systemImage: "magnifyingglass").frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(filtered, id: \.title) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.title.uppercased()).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(theme.faint)
                                ForEach(group.items, id: \.name) { item in
                                    HStack {
                                        Text(item.name).font(.system(size: 13))
                                        Spacer()
                                        KeyCap(keys: item.keys)
                                    }
                                }
                            }
                        }
                    }
                    .padding(Metrics.s4)
                }
            }
            Divider()
            Text("Settings ▸ Shortcuts has the same list. Press esc to close.")
                .font(.caption).foregroundStyle(theme.faint).padding(.vertical, 6)
        }
        .frame(width: 560, height: 480)
        .onAppear { focused = true }
    }
}
