import SwiftUI
import Observation
import BetterTerminalCore

@MainActor @Observable
final class AppModel {
    var state: AppState { didSet { scheduleSave() } }
    @ObservationIgnored let store: WorkspaceStore
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var sessions: [UUID: TerminalSession] = [:]
    @ObservationIgnored private let integrationDir: URL

    // UI triggers (keyboard shortcuts)
    var paletteOpen = false
    var layoutPickerOpen = false
    var historyOpenTab: UUID?
    /// Bumped when a shell exits and is relaunched, so views rebuild.
    var restartCounter = 0

    init() {
        let store: WorkspaceStore
        if let s = try? WorkspaceStore(directory: WorkspaceStore.defaultDirectory()) {
            store = s
        } else {
            // Fallback so the app still launches if Application Support is unwritable.
            store = try! WorkspaceStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("BetterTerminal-\(UUID().uuidString)"))
        }
        self.store = store
        self.integrationDir = store.directory.appendingPathComponent("shell-integration", isDirectory: true)
        self.state = store.loadState()
    }

    // MARK: Derived
    var theme: Theme { Theme.named(state.themeID) }
    var colorScheme: ColorScheme? {
        switch state.themeMode { case .system: nil; case .light: .light; case .dark: .dark }
    }
    var activeIndex: Int? { state.workspaces.firstIndex { $0.id == state.activeWorkspaceID } }
    var active: Workspace? { activeIndex.map { state.workspaces[$0] } }

    func mutateActive(_ body: (inout Workspace) -> Void) {
        guard let i = activeIndex else { return }
        body(&state.workspaces[i])
    }

    // MARK: Workspaces
    func addWorkspace() {
        let palette = ["#0A84FF", "#30B26B", "#FF7A45", "#8E6CF0", "#FF375F", "#64D2FF"]
        var ws = Workspace(name: "Workspace \(state.workspaces.count + 1)",
                           colorHex: palette[state.workspaces.count % palette.count])
        ws.addTab()
        state.workspaces.append(ws)
        state.activeWorkspaceID = ws.id
    }

    func deleteWorkspace(_ id: UUID) {
        guard state.workspaces.count > 1,
              let i = state.workspaces.firstIndex(where: { $0.id == id }) else { return }
        state.workspaces[i].tabs.forEach {
            sessions[$0.id]?.terminate(); sessions[$0.id] = nil
            store.deleteHistory(tab: $0.id)
        }
        state.workspaces.remove(at: i)
        if state.activeWorkspaceID == id { state.activeWorkspaceID = state.workspaces[max(0, i - 1)].id }
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = state.workspaces.firstIndex(where: { $0.id == id }), !name.isEmpty else { return }
        state.workspaces[i].name = name
    }

    func setColor(_ id: UUID, hex: String) {
        guard let i = state.workspaces.firstIndex(where: { $0.id == id }) else { return }
        state.workspaces[i].colorHex = hex
    }

    func selectWorkspace(at index: Int) {
        guard state.workspaces.indices.contains(index) else { return }
        state.activeWorkspaceID = state.workspaces[index].id
    }

    func moveWorkspaces(from: IndexSet, to: Int) { state.workspaces.move(fromOffsets: from, toOffset: to) }

    // MARK: Tabs
    func newTab() { mutateActive { $0.addTab() } }

    func closeTab(_ id: UUID) {
        mutateActive { ws in
            guard ws.tabs.count > 1 else { return }
            ws.closeTab(id)
        }
        sessions[id]?.terminate(); sessions[id] = nil
        store.deleteHistory(tab: id)
    }

    func setLayout(_ layout: PaneLayout) { mutateActive { $0.layout = layout } }

    // MARK: Terminal sessions
    func session(for tab: TerminalTab) -> TerminalSession {
        if let s = sessions[tab.id] { return s }
        let id = tab.id
        let s = SwiftTermSession(tab: tab, integrationDir: integrationDir, callbacks: .init(
            onCommand: { [weak self] in self?.record($0, tab: id) },
            onCwd: { [weak self] in self?.updateCwd(tab: id, to: $0) },
            onTitle: { [weak self] in self?.setTitle(tab: id, $0) },
            onExit: { [weak self] _ in self?.restart(tab: id) },
            onFocus: { [weak self] in self?.focusTab(id) }))
        sessions[id] = s
        return s
    }

    func activeSession() -> TerminalSession? {
        guard let ws = active, let id = ws.activeTabID, let tab = ws.tabs.first(where: { $0.id == id }) else { return nil }
        return session(for: tab)
    }

    private func restart(tab id: UUID) {
        sessions[id] = nil
        guard state.workspaces.contains(where: { $0.tabs.contains { $0.id == id } }) else { return }
        restartCounter += 1
    }

    private func focusTab(_ id: UUID) {
        guard let wi = state.workspaces.firstIndex(where: { $0.tabs.contains { $0.id == id } }),
              state.workspaces[wi].activeTabID != id else { return }
        state.workspaces[wi].activeTabID = id
    }

    private func setTitle(tab id: UUID, _ title: String) {
        for wi in state.workspaces.indices {
            if let ti = state.workspaces[wi].tabs.firstIndex(where: { $0.id == id }),
               state.workspaces[wi].tabs[ti].title != title, !title.isEmpty {
                state.workspaces[wi].tabs[ti].title = title
            }
        }
    }

    func toggleHistory() { historyOpenTab = historyOpenTab == nil ? active?.activeTabID : nil }

    /// Most recent commands across the active workspace (for the palette).
    func recentHistory(limit: Int = 40) -> [HistoryEntry] {
        guard let ws = active else { return [] }
        return ws.tabs.flatMap { store.history(tab: $0.id, limit: limit) }
            .sorted { $0.startedAt > $1.startedAt }.prefix(limit).map { $0 }
    }

    // MARK: History
    func record(_ entry: HistoryEntry, tab: UUID) { try? store.append(entry, tab: tab) }

    func updateCwd(tab id: UUID, to cwd: String) {
        for wi in state.workspaces.indices {
            if let ti = state.workspaces[wi].tabs.firstIndex(where: { $0.id == id }),
               state.workspaces[wi].tabs[ti].cwd != cwd {
                state.workspaces[wi].tabs[ti].cwd = cwd
            }
        }
    }

    // MARK: Persistence (debounced)
    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = state
        let store = store
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            try? store.saveState(snapshot)
        }
    }

    func saveNow() { saveTask?.cancel(); try? store.saveState(state) }
}
