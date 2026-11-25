import SwiftUI

/// One shortcut. `run` is what ⏎ does in the popup; it is nil for gestures and key combinations that cannot be run
/// from here (middle-click, drag, arrow keys, a range like ⌃⌘1–9...).
struct ShortcutItem: Identifiable {
    let name: String
    let keys: String
    let run: (@MainActor (AppModel) -> Void)?
    var id: String { name }
    var isRunnable: Bool { run != nil }
}

struct ShortcutGroup: Identifiable {
    let title: String
    let items: [ShortcutItem]
    var id: String { title }
}

/// Every shortcut in one place: used by the popup (⌘/) and by Settings.
/// Plain structs and small helpers keep the type checker fast (big tuple literals made it give up).
enum ShortcutCatalog {
    private static func item(_ name: String, _ keys: String, run: (@MainActor (AppModel) -> Void)? = nil) -> ShortcutItem {
        ShortcutItem(name: name, keys: keys, run: run)
    }

    private static let tabs: [ShortcutItem] = [
        item("New tab", "⌘T") { $0.route = .terminal; $0.newTab() },
        item("Close tab", "⌘W") { m in if let id = m.active?.activeTabID { m.requestCloseTab(id) } },
        item("New workspace", "⇧⌘N") { $0.addWorkspace() },
        item("Switch workspace", "⌃⌘1–9"),
        item("Close tab with middle-click", "middle-click"),
        item("Rename tab", "double-click") { m in
            if let tab = m.active?.tabs.first(where: { $0.id == m.active?.activeTabID }) { m.beginRenameTab(tab) }
        }
    ]
    private static let panes: [ShortcutItem] = [
        item("Split right", "⌘D") { $0.split(.right) },
        item("Split down", "⇧⌘D") { $0.split(.down) },
        item("Move between panes", "⌘← ↑ ↓ →"),
        item("Pane layout", "⌥⌘L") { $0.route = .terminal; $0.layoutPickerOpen = true },
        item("Broadcast typing to all panes", "⌥⌘B") { $0.toggleBroadcast() },
        item("Swap two panes", "drag header")
    ]
    private static let search: [ShortcutItem] = [
        item("Command palette", "⌘K") { $0.paletteOpen = true },
        item("Palette: Actions ⇄ Commands", "← →"),
        item("Command history (this tab)", "⇧⌘H") { $0.route = .terminal; $0.toggleHistory() },
        item("Find in terminal", "⌘F") { $0.openFind() },
        item("Find next / previous", "⌘G / ⇧⌘G")
    ]
    private static let terminal: [ShortcutItem] = [
        item("Copy last command output", "⌥⌘C") { $0.copyLastOutput() },
        item("Bigger / smaller text", "⌘+ / ⌘−"),
        item("Quick terminal", "⌃` (changeable)") { _ in QuickTerminal.shared.toggle() },
        item("Open a link", "click or ⌘-click"),
        item("Keyboard shortcuts", "⌘/"),
        item("Settings", "⌘,") { $0.route = .settings }
    ]

    static let groups: [ShortcutGroup] = [
        ShortcutGroup(title: "Tabs and workspaces", items: tabs),
        ShortcutGroup(title: "Panes", items: panes),
        ShortcutGroup(title: "Search and history", items: search),
        ShortcutGroup(title: "Terminal", items: terminal)
    ]
}

private struct KeyCap: View {
    @Environment(\.theme) private var theme
    let keys: String

    var body: some View {
        Text(keys)
            .font(.system(size: 11.5, design: .rounded))
            .foregroundStyle(theme.muted)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(theme.track, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// A quick look at all shortcuts, in a popup like the search palette. Type to filter, ↑↓ to move the highlight
/// (it wraps around), ⏎ to run the highlighted shortcut, esc or a click outside to close.
/// Shortcuts that are gestures or key combinations (middle-click, drag, the arrow keys...) cannot be run from here:
/// they are shown dimmed and ⏎ explains it instead.
struct ShortcutsPopup: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool

    private func dismiss() { model.shortcutsOpen = false }

    private var filtered: [ShortcutGroup] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return ShortcutCatalog.groups }
        var result: [ShortcutGroup] = []
        for group in ShortcutCatalog.groups {
            var hits: [ShortcutItem] = []
            for item in group.items where item.name.localizedCaseInsensitiveContains(q) || item.keys.localizedCaseInsensitiveContains(q) {
                hits.append(item)
            }
            if !hits.isEmpty { result.append(ShortcutGroup(title: group.title, items: hits)) }
        }
        return result
    }

    /// Every visible shortcut in order, which is what the arrow keys walk through.
    private var flat: [ShortcutItem] { filtered.flatMap { $0.items } }

    private var highlighted: ShortcutItem? {
        let items = flat
        return items.indices.contains(selection) ? items[selection] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 560, height: 480)
        .onAppear { focused = true }
        .onChange(of: query) { selection = 0 }
    }

    private var footer: some View {
        Group {
            if let item = highlighted, !item.isRunnable {
                Text("“\(item.name)” is a gesture or key combination: use the keys, it can't be run from here")
            } else {
                Text("↑↓ move · ⏎ run · esc or click outside to close")
            }
        }
        .font(.caption).foregroundStyle(theme.faint)
        .lineLimit(1).truncationMode(.tail)
        .padding(.horizontal, Metrics.s4).padding(.vertical, 6)
    }

    private func move(_ delta: Int) {
        let n = flat.count
        guard n > 0 else { return }
        selection = (selection + delta + n) % n
    }

    /// ⏎: closes the popup and runs the highlighted shortcut. Does nothing for a shortcut that cannot be run.
    private func runSelected() {
        guard let item = highlighted, let run = item.run else { NSSound.beep(); return }
        dismiss()
        // After the popup is gone, so the action sees the terminal and its focus, not the popup.
        DispatchQueue.main.async { run(model) }
    }

    private var searchField: some View {
        HStack(spacing: Metrics.s2) {
            Image(systemName: "keyboard").foregroundStyle(theme.muted)
            TextField("Search shortcuts", text: $query)
                .textFieldStyle(.plain).font(.title3).focused($focused)
                .onSubmit { runSelected() }
                .onKeyPress(.downArrow) { move(1); return .handled }
                .onKeyPress(.upArrow) { move(-1); return .handled }
                .onKeyPress(.escape) { dismiss(); return .handled }
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(theme.faint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(Metrics.s4)
    }

    @ViewBuilder private var content: some View {
        let groups = filtered
        if groups.isEmpty {
            ContentUnavailableView("No matching shortcuts", systemImage: "magnifyingglass").frame(maxHeight: .infinity)
        } else {
            let items = flat
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(groups) { group in
                            groupView(group, items: items)
                        }
                    }
                    .padding(Metrics.s4)
                }
                .onChange(of: selection) {
                    if items.indices.contains(selection) { proxy.scrollTo(items[selection].id) }
                }
            }
        }
    }

    private func groupView(_ group: ShortcutGroup, items: [ShortcutItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.title.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(theme.faint)
                .padding(.bottom, 4)
            ForEach(group.items) { item in
                row(item, items: items)
            }
        }
    }

    private func row(_ item: ShortcutItem, items: [ShortcutItem]) -> some View {
        let isHighlighted = items.indices.contains(selection) && items[selection].id == item.id
        return HStack(spacing: 8) {
            Text(item.name)
                .font(.system(size: 13))
                .foregroundStyle(item.isRunnable ? Color.primary : theme.muted)
            Spacer()
            if isHighlighted && item.isRunnable {
                Image(systemName: "return").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(theme.accent)
                    .transition(.opacity)
            }
            KeyCap(keys: item.keys)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(isHighlighted ? theme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { if let k = items.firstIndex(where: { $0.id == item.id }) { selection = k } }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            if let k = items.firstIndex(where: { $0.id == item.id }) { selection = k; runSelected() }
        })
        .id(item.id)
    }
}
