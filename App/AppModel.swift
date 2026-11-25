import SwiftUI
import Observation
import BetterTerminalCore
import UserNotifications

enum AppRoute: Hashable { case terminal, settings }

@MainActor @Observable
final class AppModel {
    var state: AppState { didSet { scheduleSave() } }
    @ObservationIgnored let store: WorkspaceStore
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var sessions: [UUID: TerminalSession] = [:]
    /// Template commands waiting for their shell's first prompt.
    @ObservationIgnored private var pendingStartup: [UUID: String] = [:]
    @ObservationIgnored private var focusTask: Task<Void, Never>?
    /// Sample "running" and "failed" marks for the sidebar snapshots (CI only).
    @ObservationIgnored var sampleRunning: Set<UUID> = []
    @ObservationIgnored var sampleFailed: Set<UUID> = []
    /// Terminal text that was on screen when the user pressed "Clear saved text": never saved again.
    @ObservationIgnored private var clearedBaseline: [UUID: String] = [:]
    @ObservationIgnored private let integrationDir: URL
    @ObservationIgnored private let eventsDir: URL

    // UI triggers (keyboard shortcuts)
    var route: AppRoute = .terminal
    var paletteOpen = false
    var shortcutsOpen = false
    var walkthroughOpen = false
    /// Tab being renamed (the alert lives in RootView) and the text typed so far.
    var renamingTab: UUID?
    var renameText = ""
    /// The pane that was just navigated to, for the highlight pulse. `flashID` changes on every move.
    var flashTab: UUID?
    var flashID = 0
    /// Tabs with a command running now, and tabs whose last command failed while you were elsewhere.
    var runningTabs: Set<UUID> = []
    var failedTabs: Set<UUID> = []
    /// Find bar (⌘F) for the active pane.
    var quickStatus = ""
    var findOpen = false
    var findQuery = ""
    var findMissed = false
    var layoutPickerOpen = false
    var historyOpenTab: UUID?
    /// Bumped when a shell exits and is relaunched, so views rebuild.
    var restartCounter = 0

    init() {
        let store: WorkspaceStore
        // The CI test modes (smoke, focus, sidebar snapshots) add workspaces and tabs: they must never touch your real data.
        let isTestRun = ["--smoke-test", "--focus-test", "--render-sidebar"].contains { CommandLine.arguments.contains($0) }
        let directory = isTestRun
            ? FileManager.default.temporaryDirectory.appendingPathComponent("BetterTerminal-test-\(UUID().uuidString)")
            : WorkspaceStore.defaultDirectory()
        if let s = try? WorkspaceStore(directory: directory) {
            store = s
        } else {
            // Fallback so the app still launches if Application Support is unwritable.
            store = try! WorkspaceStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("BetterTerminal-\(UUID().uuidString)"))
        }
        self.store = store
        self.integrationDir = store.directory.appendingPathComponent("shell-integration", isDirectory: true)
        self.eventsDir = store.directory.appendingPathComponent("events", isDirectory: true)
        self.state = store.loadState()
        Theme.custom = state.customThemes.map(Theme.init(custom:))
        if state.notifyLongCommands { Notifier.shared.requestAuthorization() }
        Notifier.shared.onOpenTab = { [weak self] id in self?.select(tab: id); NSApp.activate(ignoringOtherApps: true) }
        QuickTerminal.shared.attach(model: self)
        for name in [NSApplication.didBecomeActiveNotification, NSWindow.didBecomeKeyNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.scheduleFocusSync() }
            }
        }
        if state.quickTerminalEnabled { QuickTerminal.shared.start(model: self) }
        if let i = CommandLine.arguments.firstIndex(of: "--render-sidebar") {
            let out = CommandLine.arguments.indices.contains(i + 1) ? CommandLine.arguments[i + 1] : "/tmp/bt-sidebar"
            runSidebarSnapshots(into: out)
        }
        if let i = CommandLine.arguments.firstIndex(of: "--focus-test") {
            let out = CommandLine.arguments.indices.contains(i + 1) ? CommandLine.arguments[i + 1] : "/tmp/bt-focus.txt"
            runFocusTest(resultPath: out)
        }
        if let i = CommandLine.arguments.firstIndex(of: "--smoke-test") {
            let out = CommandLine.arguments.indices.contains(i + 1) ? CommandLine.arguments[i + 1] : "/tmp/bt-smoke.txt"
            runSmokeTest(resultPath: out)
        }
        // Keep the saved terminal text fresh in case of a crash or force quit.
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self else { return }
                self.saveSnapshots()
            }
        }
    }

    // MARK: Derived
    /// Built in themes plus imported ones. Reads the saved state, so views using it update when one is added or removed.
    var allThemes: [Theme] { Theme.all + state.customThemes.map(Theme.init(custom:)) }
    var theme: Theme { allThemes.first { $0.id == state.themeID } ?? Theme.all[0] }
    /// The imported theme in use, if any. Those have one look (light or dark), so they decide the appearance.
    /// Tabs with a command running right now, counting only tabs that still exist.
    var runningCount: Int {
        state.workspaces.reduce(0) { $0 + $1.tabs.filter { runningTabs.contains($0.id) }.count }
    }

    /// Running tabs (a count) or a failed command in a workspace, for the sidebar.
    func activity(of ws: Workspace) -> WorkspaceActivity {
        let running = ws.tabs.filter { runningTabs.contains($0.id) }.count
        if running > 0 { return .running(running) }
        return ws.tabs.contains { failedTabs.contains($0.id) } ? .failed : .none
    }

    /// Folder of the tab you are looking at (the quick terminal opens there when launched from inside the app).
    var activeTabFolder: String? { active?.tabs.first { $0.id == active?.activeTabID }?.cwd }
    var activeCustomTheme: CustomTheme? { state.customThemes.first { "custom-" + $0.id == state.themeID } }
    /// Applies System / Light / Dark to the whole app. `NSApp.appearance = nil` is what makes "System" follow macOS
    /// again; SwiftUI's `preferredColorScheme(nil)` does not undo an earlier Light or Dark choice.
    func applyAppearance() {
        // An imported theme is either light or dark; forcing the matching appearance keeps text readable
        // (a dark theme under a light Mac used to give black text on a dark window).
        let mode = activeCustomTheme.map { $0.isDark ? ThemeMode.dark : ThemeMode.light } ?? state.themeMode
        switch mode {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
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
            clearedBaseline[$0.id] = nil
            runningTabs.remove($0.id); failedTabs.remove($0.id)      // no phantom "running" after the workspace is gone
            store.deleteHistory(tab: $0.id)
            store.deleteSnapshot(tab: $0.id)
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
        route = .terminal
    }

    func moveWorkspaces(from: IndexSet, to: Int) { state.workspaces.move(fromOffsets: from, toOffset: to) }

    // MARK: Tabs
    func newTab() { mutateActive { $0.addTab() } }

    /// Adds a terminal to a specific workspace (sidebar context menu) and shows it.
    func newTab(in workspaceID: UUID) {
        guard let i = state.workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }
        state.workspaces[i].addTab()
        state.activeWorkspaceID = workspaceID
        route = .terminal
    }

    /// Closes a tab from the UI. If a command is running, asks first (unless the user turned that off).
    func requestCloseTab(_ id: UUID) {
        guard canCloseTab(id) else { return }
        guard state.confirmCloseRunning, sessions[id]?.hasRunningCommand == true,
              let tab = state.workspaces.lazy.flatMap({ $0.tabs }).first(where: { $0.id == id }) else {
            closeTab(id); return
        }
        let alert = NSAlert()
        alert.messageText = "Close “\(tab.title)”?"
        alert.informativeText = "A command is still running in this tab. Closing it will stop the command."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Close Tab")
        alert.addButton(withTitle: "Cancel")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don’t ask me again"
        let finish: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self, response == .alertFirstButtonReturn else { return }
            if alert.suppressionButton?.state == .on { self.state.confirmCloseRunning = false }
            self.closeTab(id)
        }
        if let window = NSApp.keyWindow { alert.beginSheetModal(for: window, completionHandler: finish) }
        else { finish(alert.runModal()) }
    }

    /// A workspace always keeps at least one tab, so its last tab can't be closed.
    func canCloseTab(_ id: UUID) -> Bool {
        state.workspaces.contains { $0.tabs.count > 1 && $0.tabs.contains { $0.id == id } }
    }

    /// Opens the tab (switching workspace if needed) and shows the terminal.
    func select(tab id: UUID) {
        guard let wi = state.workspaces.firstIndex(where: { $0.tabs.contains { $0.id == id } }) else { return }
        state.activeWorkspaceID = state.workspaces[wi].id
        state.workspaces[wi].activeTabID = id
        route = .terminal
        failedTabs.remove(id)
    }

    func closeTab(_ id: UUID) {
        guard let wi = state.workspaces.firstIndex(where: { $0.tabs.contains { $0.id == id } }),
              state.workspaces[wi].tabs.count > 1 else { return }
        state.workspaces[wi].closeTab(id)
        sessions[id]?.terminate(); sessions[id] = nil
        clearedBaseline[id] = nil
        runningTabs.remove(id); failedTabs.remove(id)
        store.deleteHistory(tab: id)
        store.deleteSnapshot(tab: id)
    }

    // MARK: Reorder / move / rename

    /// Drag payloads: "tab:<uuid>" and "ws:<uuid>".
    static func tabPayload(_ id: UUID) -> String { "tab:\(id.uuidString)" }
    static func workspacePayload(_ id: UUID) -> String { "ws:\(id.uuidString)" }

    private func payloadID(_ items: [String], prefix: String) -> UUID? {
        items.lazy.compactMap { $0.hasPrefix(prefix) ? UUID(uuidString: String($0.dropFirst(prefix.count))) : nil }.first
    }

    /// A drag was dropped on a tab: put the dragged tab in front of it (same or another workspace).
    func handleDrop(_ items: [String], ontoTab target: UUID) -> Bool {
        guard let tab = payloadID(items, prefix: "tab:"),
              let ws = state.workspaces.first(where: { $0.tabs.contains { $0.id == target } }) else { return false }
        return state.moveTab(tab, toWorkspace: ws.id, before: target)
    }

    /// A drag was dropped on a workspace row: a tab joins that workspace, a workspace moves in front of it.
    func handleDrop(_ items: [String], ontoWorkspace target: UUID) -> Bool {
        if let tab = payloadID(items, prefix: "tab:") { return state.moveTab(tab, toWorkspace: target) }
        if let ws = payloadID(items, prefix: "ws:") { return state.moveWorkspace(ws, before: target) }
        return false
    }

    /// A workspace was dropped after the last row.
    func handleDropAtEnd(_ items: [String]) -> Bool {
        guard let ws = payloadID(items, prefix: "ws:") else { return false }
        return state.moveWorkspace(ws, before: nil)
    }

    /// Dropped on the "New Workspace" row: a tab gets a workspace of its own, a workspace moves to the end.
    func handleDropOnNewWorkspace(_ items: [String]) -> Bool {
        if let tab = payloadID(items, prefix: "tab:") { moveTabToNewWorkspace(tab); return true }
        return handleDropAtEnd(items)
    }

    func moveTab(_ id: UUID, toWorkspace workspaceID: UUID) { state.moveTab(id, toWorkspace: workspaceID) }

    /// Moves a tab into a brand-new workspace.
    func moveTabToNewWorkspace(_ id: UUID) {
        guard let current = state.workspaces.first(where: { $0.tabs.contains { $0.id == id } }) else { return }
        let palette = ["#0A84FF", "#30B26B", "#FF7A45", "#8E6CF0", "#FF375F", "#64D2FF"]
        let ws = Workspace(name: "Workspace \(state.workspaces.count + 1)",
                           colorHex: palette[state.workspaces.count % palette.count], layout: current.layout)
        state.workspaces.append(ws)
        state.moveTab(id, toWorkspace: ws.id)
    }

    func beginRenameTab(_ tab: TerminalTab) { renameText = tab.title; renamingTab = tab.id }

    func commitRenameTab() {
        if let id = renamingTab { state.renameTab(id, to: renameText) }
        renamingTab = nil
    }

    func setLayout(_ layout: PaneLayout) { mutateActive { $0.layout = layout } }

    // MARK: Terminal sessions
    func session(for tab: TerminalTab) -> TerminalSession {
        if let s = sessions[tab.id] { return s }
        let id = tab.id
        let s = SwiftTermSession(tab: tab, integrationDir: integrationDir,
                                eventFile: eventsDir.appendingPathComponent("\(tab.id.uuidString).log"),
                                restoredText: state.restoreTerminalText ? store.loadSnapshot(tab: tab.id) : nil, callbacks: .init(
            onCommand: { [weak self] in self?.record($0, tab: id) },
            onCwd: { [weak self] in self?.updateCwd(tab: id, to: $0) },
            onTitle: { [weak self] in self?.setTitle(tab: id, $0) },
            onExit: { [weak self] _ in self?.restart(tab: id) },
            onFocus: { [weak self] in self?.focusTab(id) },
            onRunning: { [weak self] running in self?.setRunning(running, tab: id) },
            onReady: { [weak self] in self?.runStartupCommand(tab: id) },
            onAttach: { [weak self] in self?.scheduleFocusSync() },
            rightClickCopies: { [weak self] in self?.state.rightClickCopies ?? false },
            onMenu: { [weak self] action in self?.menuAction(action, tab: id) }))
        s.onInput = { [weak self] data in self?.mirror(data, from: id) }
        s.onPaste = { [weak self] in self?.mirrorPaste(from: id) }
        sessions[id] = s
        if let cmd = tab.startupCommand, !cmd.isEmpty {
            // Template tabs: wait for the shell's first prompt (so slow or interactive start-up files don't swallow
            // the command). If no prompt signal ever arrives, give up after a while instead of typing blindly.
            pendingStartup[id] = cmd
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(15))
                if self?.pendingStartup.removeValue(forKey: id) != nil {
                    Diagnostics.log("startup command skipped: shell never reported a prompt")
                    self?.clearStartupCommand(tab: id)
                }
            }
        }
        return s
    }

    func activeSession() -> TerminalSession? {
        guard let ws = active, let id = ws.activeTabID, let tab = ws.tabs.first(where: { $0.id == id }) else { return nil }
        return session(for: tab)
    }

    private func restart(tab id: UUID) {
        saveSnapshot(of: id)               // keep the text when the shell exits and a new one starts
        sessions[id] = nil
        runningTabs.remove(id)             // the shell is gone: nothing is running in this tab any more
        guard state.workspaces.contains(where: { $0.tabs.contains { $0.id == id } }) else { return }
        restartCounter += 1
    }

    private func focusTab(_ id: UUID) {
        guard let wi = state.workspaces.firstIndex(where: { $0.tabs.contains { $0.id == id } }),
              state.workspaces[wi].activeTabID != id else { return }
        state.workspaces[wi].activeTabID = id
        failedTabs.remove(id)
    }

    private func setTitle(tab id: UUID, _ title: String) {
        for wi in state.workspaces.indices {
            if let ti = state.workspaces[wi].tabs.firstIndex(where: { $0.id == id }), !title.isEmpty {
                // Always remember what the shell calls the tab; show it unless the user chose a name.
                if state.workspaces[wi].tabs[ti].shellTitle != title { state.workspaces[wi].tabs[ti].shellTitle = title }
                if !state.workspaces[wi].tabs[ti].hasCustomTitle, state.workspaces[wi].tabs[ti].title != title {
                    state.workspaces[wi].tabs[ti].title = title
                }
            }
        }
    }

    /// ⌘+arrow: focus the neighbouring pane in the workspace grid and pulse it.
    func focusPane(_ direction: PaneDirection) {
        guard let ws = active, let activeID = ws.activeTabID,
              let current = ws.tabs.firstIndex(where: { $0.id == activeID }),
              let next = ws.layout.effective(forPaneCount: ws.tabs.count).neighbor(of: current, direction, paneCount: ws.tabs.count) else { return }
        let target = ws.tabs[next]
        mutateActive { $0.activeTabID = target.id }
        failedTabs.remove(target.id)
        session(for: target).focus()
        flashTab = target.id
        flashID += 1
    }

    func toggleHistory() { historyOpenTab = historyOpenTab == nil ? active?.activeTabID : nil }

    /// Most recent commands across the active workspace (for the palette).
    func recentHistory(limit: Int = 40) -> [HistoryEntry] {
        guard let ws = active else { return [] }
        return ws.tabs.flatMap { store.history(tab: $0.id, limit: limit) }
            .sorted { $0.startedAt > $1.startedAt }.prefix(limit).map { $0 }
    }

    // MARK: History
    func record(_ entry: HistoryEntry, tab: UUID) {
        do { try store.append(entry, tab: tab) } catch { Diagnostics.log("history append failed: \(error.localizedDescription)") }
        finished(entry, tab: tab)
    }

    func updateCwd(tab id: UUID, to cwd: String) {
        for wi in state.workspaces.indices {
            if let ti = state.workspaces[wi].tabs.firstIndex(where: { $0.id == id }),
               state.workspaces[wi].tabs[ti].cwd != cwd {
                state.workspaces[wi].tabs[ti].cwd = cwd
            }
        }
    }

    // MARK: Keyboard focus
    //
    // Typing must always go to the active tab. Giving a terminal the keyboard only works once its view is inside a
    // window, which is not yet true right after a new tab, split, workspace switch or coming back from Settings, and
    // nothing retried. So focus is reconciled centrally: whenever anything that decides "who is active" changes, when a
    // terminal view joins a window, and when the window or app becomes active, the active terminal takes the keyboard
    // (unless you are typing in a text field such as the find bar).

    struct FocusKey: Equatable {
        var workspace: UUID?
        var tab: UUID?
        var tabs: [UUID]
        var route: AppRoute
        var restarts: Int
        var overlays: [Bool]
    }

    /// Everything that can change who should have the keyboard.
    var focusKey: FocusKey {
        FocusKey(workspace: state.activeWorkspaceID, tab: active?.activeTabID, tabs: active?.tabs.map(\.id) ?? [],
                 route: route, restarts: restartCounter,
                 overlays: [paletteOpen, shortcutsOpen, walkthroughOpen, renamingTab != nil, historyOpenTab != nil,
                            layoutPickerOpen, findOpen])
    }

    /// Reconciles now and again shortly after, because SwiftUI attaches new views a moment after the state changes.
    func scheduleFocusSync() {
        focusTask?.cancel()
        focusTask = Task { @MainActor [weak self] in
            for delay in [0, 50, 150, 400] {
                if delay > 0 { try? await Task.sleep(for: .milliseconds(delay)) } else { await Task.yield() }
                if Task.isCancelled { return }
                self?.syncFocus()
            }
        }
    }

    /// Makes the active terminal the first responder. Returns true when it has the keyboard (or should keep it).
    @discardableResult
    func syncFocus() -> Bool {
        guard route == .terminal, !paletteOpen, !shortcutsOpen, !walkthroughOpen, renamingTab == nil,
              historyOpenTab == nil, !layoutPickerOpen, let session = activeSession(),
              let window = session.nsView.window else { return false }
        if session.hasKeyboardFocus { return true }
        // Someone is typing in a text field of this window (find bar, ...): leave them alone.
        if let responder = window.firstResponder, responder is NSText { return true }
        let ok = session.focus()
        if !ok { Diagnostics.log("focus: could not give the keyboard to the active terminal") }
        return ok
    }

    // MARK: Status badges, notifications

    private func setRunning(_ running: Bool, tab id: UUID) {
        if running { runningTabs.insert(id) } else { runningTabs.remove(id) }
    }

    /// True when `id` is the tab you are looking at right now.
    private func isVisible(_ id: UUID) -> Bool {
        NSApp.isActive && route == .terminal && active?.activeTabID == id
    }

    private func finished(_ entry: HistoryEntry, tab id: UUID) {
        if entry.failed, !isVisible(id) { failedTabs.insert(id) }
        guard state.notifyLongCommands, (entry.duration ?? 0) >= Notifier.longCommandSeconds, !isVisible(id),
              let tab = state.workspaces.lazy.flatMap({ $0.tabs }).first(where: { $0.id == id }) else { return }
        Notifier.shared.commandFinished(title: tab.title, command: entry.command,
                                        exitCode: entry.exitCode, duration: entry.duration ?? 0, tab: id)
    }

    func setNotifyLongCommands(_ on: Bool) {
        state.notifyLongCommands = on
        if on { Notifier.shared.requestAuthorization() }
    }

    /// The shell is at its first prompt: type the template's command once.
    private func runStartupCommand(tab id: UUID) {
        guard let cmd = pendingStartup.removeValue(forKey: id) else { return }
        clearStartupCommand(tab: id)            // never repeat it after a relaunch
        sessions[id]?.run(cmd)
    }

    private func clearStartupCommand(tab id: UUID) {
        for wi in state.workspaces.indices {
            if let ti = state.workspaces[wi].tabs.firstIndex(where: { $0.id == id }) {
                state.workspaces[wi].tabs[ti].startupCommand = nil
            }
        }
    }

    // MARK: Split, swap, broadcast

    func split(_ axis: SplitAxis) {
        route = .terminal
        mutateActive { _ = $0.split(axis) }
    }

    static func panePayload(_ id: UUID) -> String { "pane:\(id.uuidString)" }

    /// A pane header was dropped on another pane: swap them.
    func handleDrop(_ items: [String], ontoPane target: UUID) -> Bool {
        guard let dragged = payloadID(items, prefix: "pane:") else { return false }
        let ok = state.swapTabs(dragged, target)
        if ok { select(tab: dragged) }
        return ok
    }

    func toggleBroadcast() { mutateActive { $0.broadcast.toggle() } }

    /// Typing in the active pane is repeated in the other panes of a workspace that has broadcast on.
    private func mirror(_ data: ArraySlice<UInt8>, from id: UUID) {
        guard let ws = state.workspaces.first(where: { $0.tabs.contains { $0.id == id } }),
              ws.broadcast, ws.activeTabID == id else { return }
        for t in ws.tabs where t.id != id { sessions[t.id]?.sendRaw(data) }
    }

    private func mirrorPaste(from id: UUID) {
        guard let ws = state.workspaces.first(where: { $0.tabs.contains { $0.id == id } }),
              ws.broadcast, ws.activeTabID == id else { return }
        for t in ws.tabs where t.id != id { sessions[t.id]?.replayPaste() }
    }

    /// Items of a terminal's right-click menu that act on the app.
    private func menuAction(_ action: TerminalMenuAction, tab id: UUID) {
        select(tab: id)
        switch action {
        case .find: openFind()
        case .splitRight: split(.right)
        case .splitDown: split(.down)
        case .copyLastOutput: copyLastOutput(from: sessions[id])
        }
    }

    // MARK: Find

    func openFind() { route = .terminal; findOpen = true }

    func closeFind() {
        findOpen = false; findMissed = false
        activeSession()?.clearFind()
        activeSession()?.focus()
    }

    func findNext(forward: Bool = true) {
        guard let s = activeSession() else { return }
        findMissed = !findQuery.isEmpty && !s.find(findQuery, forward: forward)
    }

    // MARK: Output, folders

    /// Copies the last command's output from `session`, or from the active pane when none is given.
    func copyLastOutput(from session: TerminalSession? = nil) {
        guard let out = (session ?? activeSession())?.lastOutput else { NSSound.beep(); return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(out, forType: .string)
    }

    func revealInFinder(_ path: String) {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Opens the folder in VS Code when it is installed.
    func openInEditor(_ path: String) {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") else { return }
        NSWorkspace.shared.open([URL(fileURLWithPath: (path as NSString).expandingTildeInPath)],
                                withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }

    var hasEditor: Bool { NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") != nil }

    // MARK: Templates

    private static let workspaceColors = ["#0A84FF", "#30B26B", "#FF7A45", "#8E6CF0", "#FF375F", "#64D2FF"]

    func saveTemplate(from workspaceID: UUID? = nil) {
        guard let ws = state.workspaces.first(where: { $0.id == (workspaceID ?? state.activeWorkspaceID) }) else { return }
        state.templates.append(ws.asTemplate(named: ws.name))
    }

    func newWorkspace(from template: WorkspaceTemplate) {
        let ws = template.makeWorkspace(colorHex: Self.workspaceColors[state.workspaces.count % Self.workspaceColors.count])
        state.workspaces.append(ws)
        state.activeWorkspaceID = ws.id
        route = .terminal
    }

    func deleteTemplate(_ id: UUID) { state.templates.removeAll { $0.id == id } }

    // MARK: Themes

    /// Selects a theme. Imported themes have a single look, so the app follows their light/dark nature.
    func useTheme(_ id: String) {
        state.themeID = id
        if let c = state.customThemes.first(where: { "custom-" + $0.id == id }) {
            state.themeMode = c.isDark ? .dark : .light
        }
    }

    /// Imports colour schemes from files (.itermcolors, Ghostty / kitty style text). Returns how many worked.
    @discardableResult
    func importThemes(_ urls: [URL]) -> Int {
        var added = 0
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let t = ThemeImport.parse(data, name: url.deletingPathExtension().lastPathComponent) else {
                Diagnostics.log("theme import failed: \(url.lastPathComponent)"); continue
            }
            state.customThemes.append(t); added += 1
        }
        Theme.custom = state.customThemes.map(Theme.init(custom:))
        if added > 0, let last = state.customThemes.last { useTheme("custom-" + last.id) }
        return added
    }

    func deleteCustomTheme(_ id: String) {
        state.customThemes.removeAll { $0.id == id }
        Theme.custom = state.customThemes.map(Theme.init(custom:))
        if state.themeID == "custom-" + id { state.themeID = "default" }
    }

    // MARK: History across every tab

    struct HistoryHit: Identifiable {
        let id = UUID()
        let tab: TerminalTab
        let workspace: String
        let entry: HistoryEntry
    }

    /// Commands matching `query` from all tabs of all workspaces, newest first.
    /// An empty `query` returns the most recent commands.
    func searchAllHistory(_ query: String, limit: Int = 30) -> [HistoryHit] {
        var hits: [HistoryHit] = []
        for ws in state.workspaces {
            for tab in ws.tabs {
                for e in store.history(tab: tab.id, limit: max(limit, 30), matching: query.isEmpty ? nil : query) {
                    hits.append(HistoryHit(tab: tab, workspace: ws.name, entry: e))
                }
            }
        }
        return Array(hits.sorted { $0.entry.startedAt > $1.entry.startedAt }.prefix(limit))
    }

    /// Opens the tab and puts (or runs) the command at its prompt.
    func use(_ hit: HistoryHit, run: Bool) {
        select(tab: hit.tab.id)
        let s = session(for: hit.tab)
        if run { s.run(hit.entry.command) } else { s.insert(hit.entry.command) }
        s.focus()
    }

    // MARK: Quick terminal and smoke test

    /// A throwaway terminal that is not part of any workspace (the drop-down terminal).
    func makeEphemeralSession(name: String, cwd: String? = nil, onCwd: @escaping (String) -> Void = { _ in },
                              onExit: @escaping () -> Void) -> TerminalSession {
        let tab = TerminalTab(title: name, cwd: cwd ?? NSHomeDirectory())
        return SwiftTermSession(tab: tab, integrationDir: integrationDir,
                                eventFile: eventsDir.appendingPathComponent("\(name.replacingOccurrences(of: " ", with: "-")).log"),
                                callbacks: .init(onCommand: { _ in }, onCwd: { onCwd($0) }, onTitle: { _ in },
                                                 onExit: { _ in onExit() }, onFocus: {}))
    }

    func setQuickTerminal(_ on: Bool) {
        state.quickTerminalEnabled = on
        if on { QuickTerminal.shared.start(model: self) } else { QuickTerminal.shared.stop(); quickStatus = "" }
    }

    func setQuickHotkey(_ raw: String) {
        state.quickTerminalHotkey = raw
        if state.quickTerminalEnabled { QuickTerminal.shared.restart(model: self) }
    }

    /// `--focus-test <file>`: used by CI. After each way of changing the active terminal (new tab, split, ⌘-arrow,
    /// workspace switch, Settings round trip, close, palette...) it types two letters through the window's real
    /// event path and checks they arrived in the active terminal and in no other. Writes one line per step.
    private func runFocusTest(resultPath: String) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(7))
            guard let self else { return }
            var lines: [String] = []
            var failed = 0
            var counter = 0

            @MainActor func allSessions() -> [(UUID, TerminalSession)] { self.sessions.map { ($0.key, $0.value) } }

            @MainActor func check(_ name: String) async {
                try? await Task.sleep(for: .milliseconds(900))        // let focus reconciliation settle
                guard let active = self.activeSession(), let window = active.nsView.window else {
                    lines.append("FAIL \(name): no active terminal or window"); failed += 1; return
                }
                counter += 1
                let marker = "zq" + String(UnicodeScalar(UInt8(96 + (counter % 26))))
                for ch in marker {
                    let s = String(ch)
                    if let down = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                                   windowNumber: window.windowNumber, context: nil, characters: s,
                                                   charactersIgnoringModifiers: s, isARepeat: false, keyCode: 0) {
                        window.sendEvent(down)
                    }
                }
                try? await Task.sleep(for: .milliseconds(700))
                var wrong: [UUID] = []
                var gotIt = false
                for (id, session) in allSessions() {
                    let has = session.snapshotText().contains(marker)
                    if session === active { gotIt = has } else if has { wrong.append(id) }
                }
                let focus = active.hasKeyboardFocus
                if gotIt && wrong.isEmpty && focus {
                    lines.append("PASS \(name)")
                } else {
                    failed += 1
                    lines.append("FAIL \(name): active got it=\(gotIt), other terminals that got it=\(wrong.count), first responder is active=\(focus)")
                }
                for (_, session) in allSessions() { session.sendRaw([0x15][...]) }   // ctrl-U: clear the typed letters
            }

            // A fresh CI machine shows the first-launch walkthrough; a returning user does not.
            self.walkthroughOpen = false
            UserDefaults.standard.set(true, forKey: "walkthroughSeen")
            await check("launch")
            self.newTab(); await check("new tab")
            self.split(.right); await check("split right")
            self.focusPane(.left); await check("⌘← pane")
            self.focusPane(.right); await check("⌘→ pane")
            self.addWorkspace(); await check("new workspace")
            self.selectWorkspace(at: 0); await check("switch workspace")
            self.route = .settings; try? await Task.sleep(for: .milliseconds(500))
            self.route = .terminal; await check("back from Settings")
            if let id = self.active?.tabs.first?.id { self.select(tab: id); await check("select tab from sidebar") }
            if let id = self.active?.activeTabID { self.closeTab(id); await check("close active tab") }
            self.paletteOpen = true; try? await Task.sleep(for: .milliseconds(500))
            self.paletteOpen = false; await check("palette closed")
            self.newTab(in: self.state.workspaces[min(1, self.state.workspaces.count - 1)].id); await check("new tab in another workspace")

            lines.append(failed == 0 ? "ALL PASS" : "\(failed) FAILED")
            try? lines.joined(separator: "\n").write(toFile: resultPath, atomically: true, encoding: .utf8)
            exit(failed == 0 ? 0 : 1)
        }
    }

    /// `--smoke-test <file>`: used by CI. Runs a command in the first terminal and writes PASS or FAIL to the file.
    private func runSmokeTest(resultPath: String) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard let self else { return }
            let marker = "BT_SMOKE_\(Int.random(in: 1000...9999))"
            self.activeSession()?.run("echo \(marker)")
            try? await Task.sleep(for: .seconds(4))
            let text = self.activeSession()?.snapshotText() ?? ""
            let pass = text.components(separatedBy: marker).count - 1 >= 2     // typed line + output
            try? (pass ? "PASS" : "FAIL: marker not found\n" + text.suffix(400)).write(toFile: resultPath, atomically: true, encoding: .utf8)
            exit(pass ? 0 : 1)
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

    func saveNow() {
        saveTask?.cancel()
        try? store.saveState(state)
        saveSnapshots()
    }

    // MARK: Terminal text (resume on relaunch)

    private func saveSnapshot(of id: UUID) {
        guard state.restoreTerminalText, let s = sessions[id] else { return }
        let text = TerminalText.prepare(s.snapshotText())
        try? store.saveSnapshot(TerminalText.afterClear(text, baseline: clearedBaseline[id] ?? ""), tab: id)
    }

    /// Saves the text of every running terminal. Tabs that were not opened this launch keep their old snapshot.
    func saveSnapshots() {
        guard state.restoreTerminalText else { return }
        for id in sessions.keys { saveSnapshot(of: id) }
    }

    /// Deletes the saved text and makes sure what is on screen right now is not saved again.
    func clearSavedTerminalText() {
        store.clearSnapshots()
        for (id, s) in sessions { clearedBaseline[id] = TerminalText.prepare(s.snapshotText()) }
    }
}
