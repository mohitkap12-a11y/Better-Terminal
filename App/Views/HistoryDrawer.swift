import SwiftUI
import BetterTerminalCore

/// Per-tab command history. Fully keyboard driven: type to search, ↑/↓ to move through the results,
/// ⏎ puts the command at the prompt, ⌘⏎ runs it. Click = put at prompt, double-click = run.
struct HistoryDrawer: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let tab: TerminalTab
    let onPick: (_ command: String, _ runNow: Bool) -> Void

    @State private var query = ""
    @State private var failedOnly = false
    @State private var entries: [HistoryEntry] = []
    @State private var selection = 0
    @FocusState private var searchFocused: Bool

    private var shown: [HistoryEntry] { failedOnly ? entries.filter(\.failed) : entries }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.s2) {
                Image(systemName: "magnifyingglass").foregroundStyle(theme.muted)
                TextField("Search history", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onKeyPress(.downArrow) { move(1); return .handled }
                    .onKeyPress(.upArrow) { move(-1); return .handled }
                    .onKeyPress(.pageDown) { move(8); return .handled }
                    .onKeyPress(.pageUp) { move(-8); return .handled }
                    .onSubmit { pickSelected(runNow: NSEvent.modifierFlags.contains(.command)) }
                Toggle(isOn: $failedOnly) { Image(systemName: "exclamationmark.circle") }
                    .toggleStyle(.button).controlSize(.small)
                    .accessibilityLabel("Show failed only").help("Failed only")
            }
            .padding(Metrics.s3)
            Divider()
            if shown.isEmpty {
                ContentUnavailableView(query.isEmpty && !failedOnly ? "No commands yet" : "No matches",
                                       systemImage: "clock",
                                       description: Text(query.isEmpty && !failedOnly
                                                         ? "Commands you run in this tab show up here."
                                                         : "Try a different search."))
                    .frame(height: 220)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(shown.enumerated()), id: \.element.id) { index, e in
                                Row(entry: e, selected: index == selection)
                                    .id(e.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) { onPick(e.command, true) }
                                    .onTapGesture { onPick(e.command, NSEvent.modifierFlags.contains(.command)) }
                                    .contextMenu {
                                        Button("Run again") { onPick(e.command, true) }
                                        Button("Insert at prompt") { onPick(e.command, false) }
                                        Divider()
                                        Button("Copy command") { copy(e.command) }
                                        Button("Copy directory") { copy(e.cwd) }
                                    }
                            }
                        }
                        .padding(6)
                    }
                    .frame(height: 320)
                    .onChange(of: selection) {
                        if shown.indices.contains(selection) { proxy.scrollTo(shown[selection].id) }
                    }
                }
                Divider()
                HStack(spacing: Metrics.s3) {
                    hint("↑↓", "navigate"); hint("⏎", "insert"); hint("⌘⏎", "run")
                }
                .padding(.horizontal, Metrics.s3).padding(.vertical, 6)
            }
        }
        .frame(width: 380)
        .onAppear { searchFocused = true }
        .onChange(of: query) { selection = 0 }
        .onChange(of: failedOnly) { selection = 0 }
        .task(id: query) {
            entries = model.store.history(tab: tab.id, limit: 500, matching: query)
            selection = 0
        }
    }

    private func move(_ delta: Int) {
        guard !shown.isEmpty else { return }
        selection = min(max(selection + delta, 0), shown.count - 1)
    }

    private func pickSelected(runNow: Bool) {
        guard shown.indices.contains(selection) else { return }
        onPick(shown[selection].command, runNow)
    }

    private func hint(_ keys: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(keys).font(.system(size: 10.5, weight: .medium, design: .rounded))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(theme.track, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text(label).font(.system(size: 10.5)).foregroundStyle(theme.faint)
        }
    }

    private func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    private struct Row: View {
        @Environment(\.theme) private var theme
        let entry: HistoryEntry
        let selected: Bool

        var body: some View {
            HStack(spacing: Metrics.s2) {
                Circle().fill(entry.failed ? Color.red : Color.green).frame(width: 6, height: 6)
                    .accessibilityLabel(entry.failed ? "Failed" : "Succeeded")
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.command).font(.system(.callout, design: .monospaced))
                        .lineLimit(1).truncationMode(.middle)
                    Text(entry.cwd.replacingOccurrences(of: NSHomeDirectory(), with: "~") + " · " + entry.startedAt.formatted(.relative(presentation: .named)))
                        .font(.caption2).foregroundStyle(theme.muted).lineLimit(1).truncationMode(.head)
                }
                Spacer()
                if let d = entry.duration {
                    Text(String(format: "%.1fs", d)).font(.caption2).monospacedDigit().foregroundStyle(theme.faint)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(selected ? theme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}
