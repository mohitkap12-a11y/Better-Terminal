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

    public init(id: UUID = UUID(), title: String = "Terminal",
                cwd: String = NSHomeDirectory(), shell: String = "/bin/zsh") {
        self.id = id; self.title = title; self.cwd = cwd; self.shell = shell
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
