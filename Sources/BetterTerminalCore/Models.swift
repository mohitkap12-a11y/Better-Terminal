import Foundation

public struct HistoryEntry: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var command: String
    public var cwd: String
    public var exitCode: Int32?
    public var startedAt: Date
    public var duration: TimeInterval?

    public init(id: UUID = UUID(), command: String, cwd: String,
                exitCode: Int32? = nil, startedAt: Date = Date(), duration: TimeInterval? = nil) {
        self.id = id; self.command = command; self.cwd = cwd
        self.exitCode = exitCode; self.startedAt = startedAt; self.duration = duration
    }

    public var failed: Bool { (exitCode ?? 0) != 0 }
}

/// A terminal pane/tab. History lives in a separate per-tab store, not here.
public struct TerminalTab: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var cwd: String
    public var shell: String
    /// True once the user renamed the tab: the shell's own title updates no longer overwrite `title`.
    public var hasCustomTitle: Bool
    /// The latest title the shell set, kept while a custom name is shown so clearing the name can restore it.
    public var shellTitle: String
    /// Typed into the shell once when the tab first opens (workspace templates). Cleared after it ran.
    public var startupCommand: String?

    public init(id: UUID = UUID(), title: String = "Terminal",
                cwd: String = NSHomeDirectory(), shell: String = "/bin/zsh", hasCustomTitle: Bool = false,
                startupCommand: String? = nil) {
        self.id = id; self.title = title; self.cwd = cwd; self.shell = shell; self.hasCustomTitle = hasCustomTitle
        self.shellTitle = title; self.startupCommand = startupCommand
    }

    // Tolerant decoding: state files written before renaming existed have no `hasCustomTitle`.
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        cwd = try c.decode(String.self, forKey: .cwd)
        shell = try c.decode(String.self, forKey: .shell)
        hasCustomTitle = try c.decodeIfPresent(Bool.self, forKey: .hasCustomTitle) ?? false
        shellTitle = try c.decodeIfPresent(String.self, forKey: .shellTitle) ?? title
        startupCommand = try c.decodeIfPresent(String.self, forKey: .startupCommand)
    }
}

public struct Workspace: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var symbol: String          // SF Symbol name
    public var colorHex: String
    public var layout: PaneLayout
    public var tabs: [TerminalTab]
    public var activeTabID: UUID?
    /// Typing in one pane is sent to every pane of this workspace.
    public var broadcast: Bool = false

    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "terminal"
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "#0A84FF"
        layout = try c.decodeIfPresent(PaneLayout.self, forKey: .layout) ?? .single
        tabs = try c.decode([TerminalTab].self, forKey: .tabs)
        activeTabID = try c.decodeIfPresent(UUID.self, forKey: .activeTabID) ?? tabs.first?.id
        broadcast = try c.decodeIfPresent(Bool.self, forKey: .broadcast) ?? false
    }

    public init(id: UUID = UUID(), name: String, symbol: String = "terminal",
                colorHex: String = "#0A84FF", layout: PaneLayout = .single,
                tabs: [TerminalTab] = [], activeTabID: UUID? = nil) {
        self.id = id; self.name = name; self.symbol = symbol; self.colorHex = colorHex
        self.layout = layout; self.tabs = tabs; self.activeTabID = activeTabID ?? tabs.first?.id
    }

    /// New tabs inherit the workspace layout automatically (layout is workspace-level).
    @discardableResult
    public mutating func addTab(cwd: String? = nil) -> TerminalTab {
        let tab = TerminalTab(title: "Terminal \(tabs.count + 1)", cwd: cwd ?? tabs.last?.cwd ?? NSHomeDirectory())
        tabs.append(tab)
        activeTabID = tab.id
        return tab
    }

    /// Adds a pane next to the active one (iTerm-style split): the new tab goes right after it and the layout
    /// grows along `axis` so it has room. The new pane starts in the same folder.
    @discardableResult
    public mutating func split(_ axis: SplitAxis) -> TerminalTab {
        let at = tabs.firstIndex { $0.id == activeTabID } ?? (tabs.count - 1)
        let cwd = tabs.indices.contains(at) ? tabs[at].cwd : NSHomeDirectory()
        let tab = TerminalTab(title: "Terminal \(tabs.count + 1)", cwd: cwd)
        tabs.insert(tab, at: min(at + 1, tabs.count))
        activeTabID = tab.id
        layout = layout.growing(toFit: tabs.count, along: axis)
        return tab
    }

    public mutating func closeTab(_ id: UUID) {
        guard let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: i)
        if activeTabID == id { activeTabID = tabs.indices.contains(i) ? tabs[i].id : tabs.last?.id }
    }
}

public enum SplitAxis: Sendable { case right, down }

/// A saved workspace setup: layout plus the tabs to open (folder and an optional command each).
public struct WorkspaceTemplate: Codable, Hashable, Sendable, Identifiable {
    public struct Tab: Codable, Hashable, Sendable, Identifiable {
        public var id: UUID = UUID()
        public var title: String
        public var cwd: String
        public var command: String
        public init(title: String = "Terminal", cwd: String = NSHomeDirectory(), command: String = "") {
            self.title = title; self.cwd = cwd; self.command = command
        }
    }
    public var id: UUID
    public var name: String
    public var layout: PaneLayout
    public var tabs: [Tab]
    public init(id: UUID = UUID(), name: String, layout: PaneLayout = .single, tabs: [Tab] = []) {
        self.id = id; self.name = name; self.layout = layout; self.tabs = tabs
    }
}

extension Workspace {
    /// Captures this workspace as a template (folders only; commands are added by the user).
    public func asTemplate(named name: String) -> WorkspaceTemplate {
        WorkspaceTemplate(name: name, layout: layout,
                          tabs: tabs.map { .init(title: $0.title, cwd: $0.cwd, command: "") })
    }
}

extension WorkspaceTemplate {
    /// A new workspace with one tab per template tab.
    public func makeWorkspace(name: String? = nil, colorHex: String) -> Workspace {
        var ws = Workspace(name: name ?? self.name, colorHex: colorHex, layout: layout)
        for t in tabs {
            let tab = TerminalTab(title: t.title.isEmpty ? "Terminal" : t.title, cwd: t.cwd,
                                  hasCustomTitle: !t.title.isEmpty && t.title != "Terminal",
                                  startupCommand: t.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : t.command)
            ws.tabs.append(tab)
        }
        if ws.tabs.isEmpty { ws.addTab() }
        ws.activeTabID = ws.tabs.first?.id
        return ws
    }
}

/// A command the user keeps for reuse. Global: not tied to a tab, it runs in whichever terminal is focused.
public struct SavedCommand: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var command: String
    /// Optional label shown instead of the command (e.g. "Deploy staging"). Empty means none.
    public var name: String
    public var createdAt: Date
    public init(id: UUID = UUID(), command: String, name: String = "", createdAt: Date = Date()) {
        self.id = id; self.command = command; self.name = name; self.createdAt = createdAt
    }
    /// What lists show as the main text: the name when set, otherwise the command.
    public var title: String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? command : n
    }
    public var hasName: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

public enum ThemeMode: String, Codable, Sendable, CaseIterable { case system, light, dark }

public struct AppState: Codable, Sendable {
    public var version: Int = 2
    public var workspaces: [Workspace]
    public var activeWorkspaceID: UUID?
    public var themeMode: ThemeMode = .system
    public var themeID: String = "default"
    public var terminalFontSize: Double = 13
    /// Save each terminal's text on quit and show it again on relaunch.
    public var restoreTerminalText: Bool = true
    /// Ask before closing a tab that is running a command.
    public var confirmCloseRunning: Bool = true
    /// Notify when a command that ran this long (seconds) finishes while you are elsewhere.
    public var notifyLongCommands: Bool = true
    public var terminalFontFamily: String = ""
    public var templates: [WorkspaceTemplate] = []
    public var customThemes: [CustomTheme] = []
    /// Frequently used commands the user saved (⌘K ▸ Saved). In the user's order.
    public var savedCommands: [SavedCommand] = []
    /// Global hotkey (⌃`) that pops up a small terminal in the bottom-right corner.
    public var quickTerminalEnabled: Bool = false
    /// Which key opens the quick terminal (see `QuickHotkey` in the app).
    public var quickTerminalHotkey: String = "ctrlGrave"
    /// Right-click on selected text copies it at once instead of showing the menu.
    public var rightClickCopies: Bool = false

    public init(workspaces: [Workspace] = [], activeWorkspaceID: UUID? = nil) {
        self.workspaces = workspaces
        self.activeWorkspaceID = activeWorkspaceID ?? workspaces.first?.id
    }

    // Tolerant decoding: older state files lacking new keys still load.
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        workspaces = try c.decode([Workspace].self, forKey: .workspaces)
        activeWorkspaceID = try c.decodeIfPresent(UUID.self, forKey: .activeWorkspaceID) ?? workspaces.first?.id
        themeMode = try c.decodeIfPresent(ThemeMode.self, forKey: .themeMode) ?? .system
        themeID = try c.decodeIfPresent(String.self, forKey: .themeID) ?? "default"
        terminalFontSize = try c.decodeIfPresent(Double.self, forKey: .terminalFontSize) ?? 13
        restoreTerminalText = try c.decodeIfPresent(Bool.self, forKey: .restoreTerminalText) ?? true
        confirmCloseRunning = try c.decodeIfPresent(Bool.self, forKey: .confirmCloseRunning) ?? true
        notifyLongCommands = try c.decodeIfPresent(Bool.self, forKey: .notifyLongCommands) ?? true
        terminalFontFamily = try c.decodeIfPresent(String.self, forKey: .terminalFontFamily) ?? ""
        templates = try c.decodeIfPresent([WorkspaceTemplate].self, forKey: .templates) ?? []
        customThemes = try c.decodeIfPresent([CustomTheme].self, forKey: .customThemes) ?? []
        savedCommands = try c.decodeIfPresent([SavedCommand].self, forKey: .savedCommands) ?? []
        quickTerminalEnabled = try c.decodeIfPresent(Bool.self, forKey: .quickTerminalEnabled) ?? false
        quickTerminalHotkey = try c.decodeIfPresent(String.self, forKey: .quickTerminalHotkey) ?? "ctrlGrave"
        rightClickCopies = try c.decodeIfPresent(Bool.self, forKey: .rightClickCopies) ?? false
    }

    public static func fresh() -> AppState {
        var ws = Workspace(name: "Main")
        ws.addTab()
        return AppState(workspaces: [ws])
    }
}

// MARK: Saved commands

extension AppState {
    private static func normalized(_ command: String) -> String {
        command.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The saved entry for this command text, if any (surrounding whitespace ignored).
    public func savedCommand(for command: String) -> SavedCommand? {
        let c = Self.normalized(command)
        return savedCommands.first { Self.normalized($0.command) == c }
    }

    public func isSaved(_ command: String) -> Bool { savedCommand(for: command) != nil }

    /// Saves a command. Empty commands and duplicates are ignored. Returns whether it was added.
    @discardableResult
    public mutating func saveCommand(_ command: String, name: String = "") -> Bool {
        let c = Self.normalized(command)
        guard !c.isEmpty, !isSaved(c) else { return false }
        savedCommands.append(SavedCommand(command: c, name: name.trimmingCharacters(in: .whitespacesAndNewlines)))
        return true
    }

    /// Saves the command if it is not saved yet, otherwise removes it. Returns whether it is saved afterwards.
    @discardableResult
    public mutating func toggleSaved(_ command: String) -> Bool {
        if let s = savedCommand(for: command) { removeSavedCommand(s.id); return false }
        return saveCommand(command)
    }

    public mutating func removeSavedCommand(_ id: UUID) { savedCommands.removeAll { $0.id == id } }

    /// Moves a saved command up (negative) or down (positive), clamped to the list.
    public mutating func moveSavedCommand(_ id: UUID, by delta: Int) {
        guard let i = savedCommands.firstIndex(where: { $0.id == id }) else { return }
        let j = min(max(i + delta, 0), savedCommands.count - 1)
        guard i != j else { return }
        savedCommands.insert(savedCommands.remove(at: i), at: j)
    }

    /// Saved commands whose name or command contains `query` (case-insensitive). Empty query returns all.
    public func searchSavedCommands(_ query: String) -> [SavedCommand] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return savedCommands }
        return savedCommands.filter {
            $0.command.localizedCaseInsensitiveContains(q) || $0.name.localizedCaseInsensitiveContains(q)
        }
    }
}

// MARK: Reordering and moving

extension AppState {
    /// Moves a workspace in front of `target`, or to the end when `target` is nil.
    @discardableResult
    public mutating func moveWorkspace(_ id: UUID, before target: UUID?) -> Bool {
        guard id != target, let from = workspaces.firstIndex(where: { $0.id == id }) else { return false }
        let ws = workspaces.remove(at: from)
        if let target, let to = workspaces.firstIndex(where: { $0.id == target }) {
            workspaces.insert(ws, at: to)
        } else if target == nil {
            workspaces.append(ws)
        } else {
            workspaces.insert(ws, at: from)      // unknown target: put it back
            return false
        }
        return true
    }

    /// Moves a tab to `workspaceID`, in front of `targetTab` (or to the end). Works within one workspace
    /// (reorder) and across workspaces. The tab keeps its id, so its terminal, history and saved text follow it.
    /// A workspace never ends up without a tab: if its last tab leaves, a fresh one takes its place.
    @discardableResult
    public mutating func moveTab(_ tabID: UUID, toWorkspace workspaceID: UUID, before targetTab: UUID? = nil) -> Bool {
        guard tabID != targetTab,
              let srcW = workspaces.firstIndex(where: { $0.tabs.contains { $0.id == tabID } }),
              let dstW = workspaces.firstIndex(where: { $0.id == workspaceID }),
              let srcT = workspaces[srcW].tabs.firstIndex(where: { $0.id == tabID }) else { return false }
        if let targetTab, !workspaces[dstW].tabs.contains(where: { $0.id == targetTab }) { return false }

        let tab = workspaces[srcW].tabs.remove(at: srcT)
        if workspaces[srcW].activeTabID == tabID {
            let tabs = workspaces[srcW].tabs
            workspaces[srcW].activeTabID = tabs.indices.contains(srcT) ? tabs[srcT].id : tabs.last?.id
        }
        if workspaces[srcW].tabs.isEmpty && srcW != dstW {
            workspaces[srcW].addTab(cwd: tab.cwd)
        }
        if let targetTab, let i = workspaces[dstW].tabs.firstIndex(where: { $0.id == targetTab }) {
            workspaces[dstW].tabs.insert(tab, at: i)
        } else {
            workspaces[dstW].tabs.append(tab)
        }
        workspaces[dstW].activeTabID = tab.id
        return true
    }

    /// Swaps the positions of two tabs in the same workspace (drag a pane onto another pane).
    @discardableResult
    public mutating func swapTabs(_ a: UUID, _ b: UUID) -> Bool {
        guard a != b else { return false }
        for w in workspaces.indices {
            if let i = workspaces[w].tabs.firstIndex(where: { $0.id == a }),
               let j = workspaces[w].tabs.firstIndex(where: { $0.id == b }) {
                workspaces[w].tabs.swapAt(i, j)
                return true
            }
        }
        return false
    }

    /// Gives a tab a name of the user's choosing. An empty name goes back to the shell-provided title.
    @discardableResult
    public mutating func renameTab(_ tabID: UUID, to name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        for w in workspaces.indices {
            if let t = workspaces[w].tabs.firstIndex(where: { $0.id == tabID }) {
                if trimmed.isEmpty {
                    workspaces[w].tabs[t].hasCustomTitle = false
                    workspaces[w].tabs[t].title = workspaces[w].tabs[t].shellTitle
                } else {
                    workspaces[w].tabs[t].title = String(trimmed.prefix(60))
                    workspaces[w].tabs[t].hasCustomTitle = true
                }
                return true
            }
        }
        return false
    }
}
