import SwiftUI
import BetterTerminalCore

private struct PaletteItem: Identifiable {
    let id = UUID()
    let title: String
    var subtitle: String = ""
    let symbol: String
    let action: () -> Void
}

/// ⌘K: actions, workspaces, layouts, themes, history and AI.
struct CommandPalette: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selection = 0
    @State private var aiBusy = false
    @State private var aiText: String?
    @State private var aiIsCommand = false
    @State private var aiError: String?
    @FocusState private var focused: Bool

    private var items: [PaletteItem] {
        var all: [PaletteItem] = []
        func add(_ t: String, _ sub: String = "", _ sym: String, _ a: @escaping () -> Void) {
            all.append(PaletteItem(title: t, subtitle: sub, symbol: sym, action: { dismiss(); a() }))
        }
        add("New Tab", "⌘T", "plus.square") { model.newTab() }
        add("New Workspace", "⇧⌘N", "rectangle.stack.badge.plus") { model.addWorkspace() }
        add("Show Command History", "⇧⌘H", "clock.arrow.circlepath") { model.toggleHistory() }
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
            out.append(PaletteItem(title: e.command, subtitle: "history · " + e.cwd.replacingOccurrences(of: NSHomeDirectory(), with: "~"),
                                   symbol: e.failed ? "exclamationmark.circle" : "clock") {
                dismiss(); model.activeSession()?.insert(e.command)
            })
        }
        if !q.isEmpty {
            out.append(PaletteItem(title: "Ask AI: \(q)", subtitle: "Generate a command", symbol: "sparkles") { askCommand(q) })
        }
        if let failed = model.recentHistory(limit: 20).first(where: \.failed) {
            out.append(PaletteItem(title: "AI: explain last failure", subtitle: failed.command, symbol: "sparkles") { explain(failed) })
        }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.s2) {
                Image(systemName: "command").foregroundStyle(.secondary)
                TextField("Type a command, search history, or ask AI", text: $query)
                    .textFieldStyle(.plain).font(.title3).focused($focused)
                    .onSubmit { run(selection) }
                    .onChange(of: query) { selection = 0 }
                    .onKeyPress(.downArrow) { selection = min(selection + 1, max(items.count - 1, 0)); return .handled }
                    .onKeyPress(.upArrow) { selection = max(selection - 1, 0); return .handled }
                    .onKeyPress(.escape) { dismiss(); return .handled }
            }
            .padding(Metrics.s4)
            Divider()
            if let text = aiText {
                aiPanel(text)
            } else {
                ScrollViewReader { proxy in
                    List(Array(items.enumerated()), id: \.element.id) { i, item in
                        HStack(spacing: Metrics.s3) {
                            Image(systemName: item.symbol).frame(width: 20).foregroundStyle(.secondary)
                            Text(item.title).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(item.subtitle).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .listRowBackground(i == selection ? Color.accentColor.opacity(0.18) : Color.clear)
                        .onTapGesture { run(i) }
                        .id(i)
                    }
                    .listStyle(.plain)
                    .onChange(of: selection) { proxy.scrollTo(selection) }
                }
                if aiBusy { ProgressView("Thinking…").controlSize(.small).padding(Metrics.s2) }
                if let e = aiError { Text(e).font(.caption).foregroundStyle(.red).padding(Metrics.s2) }
            }
        }
        .frame(width: 560, height: 400)
        .onAppear { focused = true }
    }

    private func aiPanel(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Metrics.s3) {
            ScrollView {
                Text(text).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button("Back") { aiText = nil }
                Spacer()
                if aiIsCommand {
                    Button("Insert at prompt") { dismiss(); model.activeSession()?.insert(text) }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
                }
            }
            if aiIsCommand { Text("Review before running: the command is inserted, not executed.")
                .font(.caption).foregroundStyle(.secondary) }
        }
        .padding(Metrics.s4)
        .frame(maxHeight: .infinity)
    }

    private func run(_ i: Int) {
        let list = items
        guard list.indices.contains(i) else { return }
        list[i].action()
    }

    private func askCommand(_ q: String) {
        let shell = model.active?.tabs.first?.shell ?? "/bin/zsh"
        send(system: AIClient.commandSystem, user: "Shell: \(shell)\nRequest: \(q)", isCommand: true)
    }

    private func explain(_ e: HistoryEntry) {
        send(system: AIClient.explainSystem,
             user: "Command: \(e.command)\nExit code: \(e.exitCode ?? -1)\nDirectory: \(e.cwd)", isCommand: false)
    }

    private func send(system: String, user: String, isCommand: Bool) {
        aiBusy = true; aiError = nil
        let provider = model.state.aiProvider, m = model.state.aiModel
        Task {
            do {
                let r = try await AIClient.complete(system: system, user: user, provider: provider, model: m)
                aiText = r; aiIsCommand = isCommand
            } catch { aiError = error.localizedDescription }
            aiBusy = false
        }
    }
}
