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
    /// True once the user renamed the tab: the shell's own title updates no longer overwrite it.
    public var hasCustomTitle: Bool

    public init(id: UUID = UUID(), title: String = "Terminal",
                cwd: String = NSHomeDirectory(), shell: String = "/bin/zsh", hasCustomTitle: Bool = false) {
        self.id = id; self.title = title; self.cwd = cwd; self.shell = shell; self.hasCustomTitle = hasCustomTitle
    }

    // Tolerant decoding: state files written before renaming existed have no `hasCustomTitle`.
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        cwd = try c.decode(String.self, forKey: .cwd)
        shell = try c.decode(String.self, forKey: .shell)
        hasCustomTitle = try c.decodeIfPresent(Bool.self, forKey: .hasCustomTitle) ?? false
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

    public mutating func closeTab(_ id: UUID) {
        guard let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: i)
        if activeTabID == id { activeTabID = tabs.indices.contains(i) ? tabs[i].id : tabs.last?.id }
    }
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
    }

    public static func fresh() -> AppState {
        var ws = Workspace(name: "Main")
        ws.addTab()
        return AppState(workspaces: [ws])
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

    /// Gives a tab a name of the user's choosing. An empty name goes back to the shell-provided title.
    @discardableResult
    public mutating func renameTab(_ tabID: UUID, to name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        for w in workspaces.indices {
            if let t = workspaces[w].tabs.firstIndex(where: { $0.id == tabID }) {
                if trimmed.isEmpty {
                    workspaces[w].tabs[t].hasCustomTitle = false
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
