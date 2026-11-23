import SwiftUI
import BetterTerminalCore

/// Per-tab command history. Click = put at prompt. Double-click / ⌘-click = run.
struct HistoryDrawer: View {
    @Environment(AppModel.self) private var model
    let tab: TerminalTab
    let onPick: (_ command: String, _ runNow: Bool) -> Void

    @State private var query = ""
    @State private var failedOnly = false
    @State private var entries: [HistoryEntry] = []

    private var shown: [HistoryEntry] { failedOnly ? entries.filter(\.failed) : entries }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.s2) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search history", text: $query).textFieldStyle(.plain)
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
                List(shown) { e in
                    Row(entry: e)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { onPick(e.command, true) }
                        .onTapGesture { onPick(e.command, NSEvent.modifierFlags.contains(.command)) }
                        .listRowSeparator(.hidden)
                        .contextMenu {
                            Button("Run again") { onPick(e.command, true) }
                            Button("Insert at prompt") { onPick(e.command, false) }
                            Divider()
                            Button("Copy command") { copy(e.command) }
                            Button("Copy directory") { copy(e.cwd) }
                        }
                }
                .listStyle(.plain)
                .frame(height: 320)
            }
        }
        .frame(width: 360)
        .task(id: query) { entries = model.store.history(tab: tab.id, limit: 500, matching: query) }
    }

    private func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    private struct Row: View {
        let entry: HistoryEntry
        var body: some View {
            HStack(spacing: Metrics.s2) {
                Circle().fill(entry.failed ? Color.red : Color.green).frame(width: 6, height: 6)
                    .accessibilityLabel(entry.failed ? "Failed" : "Succeeded")
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.command).font(.system(.callout, design: .monospaced))
                        .lineLimit(1).truncationMode(.middle)
                    Text(entry.cwd.replacingOccurrences(of: NSHomeDirectory(), with: "~") + " · " + entry.startedAt.formatted(.relative(presentation: .named)))
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                }
                Spacer()
                if let d = entry.duration {
                    Text(String(format: "%.1fs", d)).font(.caption2).monospacedDigit().foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
