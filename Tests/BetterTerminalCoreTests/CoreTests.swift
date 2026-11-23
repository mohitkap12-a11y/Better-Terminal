import XCTest
@testable import BetterTerminalCore

final class CoreTests: XCTestCase {
    func tempStore() throws -> WorkspaceStore {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return try WorkspaceStore(directory: dir)
    }

    func testLayoutCellsRowMajor() {
        let l = PaneLayout(rows: 2, columns: 3)
        XCTAssertEqual(l.capacity, 6)
        XCTAssertEqual(l.cell(forPaneAt: 4).row, 1)
        XCTAssertEqual(l.cell(forPaneAt: 4).column, 1)
        XCTAssertEqual(l.rowsNeeded(forPaneCount: 8), 3)
    }

    func testLayoutClamps() {
        XCTAssertEqual(PaneLayout(rows: 0, columns: 99).columns, PaneLayout.maxDimension)
        XCTAssertEqual(PaneLayout(rows: 0, columns: 99).rows, 1)
    }

    func testNewTabsFollowWorkspaceLayout() {
        var ws = Workspace(name: "w", layout: PaneLayout(rows: 1, columns: 3))
        ws.addTab(); ws.addTab()
        XCTAssertEqual(ws.layout, PaneLayout(rows: 1, columns: 3))
        XCTAssertEqual(ws.tabs.count, 2)
        XCTAssertEqual(ws.activeTabID, ws.tabs.last?.id)
    }

    func testCloseTabPicksNeighbor() {
        var ws = Workspace(name: "w")
        let a = ws.addTab(), b = ws.addTab(), c = ws.addTab()
        ws.activeTabID = b.id
        ws.closeTab(b.id)
        XCTAssertEqual(ws.activeTabID, c.id)
        ws.closeTab(c.id)
        XCTAssertEqual(ws.activeTabID, a.id)
    }

    func testStateSurvivesRestart() throws {
        let s1 = try tempStore()
        var state = AppState.fresh()
        state.workspaces[0].layout = PaneLayout(rows: 2, columns: 2)
        state.themeMode = .dark
        try s1.saveState(state)
        let s2 = try WorkspaceStore(directory: s1.directory) // simulates relaunch
        let loaded = s2.loadState()
        XCTAssertEqual(loaded.workspaces[0].layout, PaneLayout(rows: 2, columns: 2))
        XCTAssertEqual(loaded.themeMode, .dark)
    }

    func testHistoryPersistsNewestFirstAndSearch() throws {
        let s = try tempStore()
        let tab = UUID()
        try s.append(HistoryEntry(command: "ls", cwd: "/"), tab: tab)
        try s.append(HistoryEntry(command: "git status", cwd: "/", exitCode: 1), tab: tab)
        let s2 = try WorkspaceStore(directory: s.directory)
        let all = s2.history(tab: tab)
        XCTAssertEqual(all.map(\.command), ["git status", "ls"])
        XCTAssertTrue(all[0].failed)
        XCTAssertEqual(s2.history(tab: tab, matching: "GIT").count, 1)
    }

    func testCorruptHistoryLineSkipped() throws {
        let s = try tempStore()
        let tab = UUID()
        try s.append(HistoryEntry(command: "ok", cwd: "/"), tab: tab)
        let url = s.directory.appendingPathComponent("history/\(tab.uuidString).jsonl")
        let h = try FileHandle(forWritingTo: url); try h.seekToEnd()
        try h.write(contentsOf: Data("{torn".utf8)); try h.close()
        XCTAssertEqual(s.history(tab: tab).map(\.command), ["ok"])
    }
}

final class IntegrationTests: XCTestCase {
    func testOldStateFileStillDecodes() throws {
        let ws = Workspace(name: "Old")
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let full = try enc.encode(AppState(workspaces: [ws]))
        var obj = try JSONSerialization.jsonObject(with: full) as! [String: Any]
        ["terminalFontSize", "aiProvider", "aiModel", "version"].forEach { obj.removeValue(forKey: $0) }
        let data = try JSONSerialization.data(withJSONObject: obj)
        let s = try JSONDecoder().decode(AppState.self, from: data)
        XCTAssertEqual(s.terminalFontSize, 13)
        XCTAssertEqual(s.workspaces.first?.name, "Old")
    }

    func testTracker() {
        var t = CommandTracker(cwd: "/tmp")
        XCTAssertNil(t.commandFinished(exitCode: 0))           // prompt with nothing pending
        t.commandStarted("  make test \n", at: Date(timeIntervalSince1970: 100))
        let e = t.commandFinished(exitCode: 2, at: Date(timeIntervalSince1970: 103))
        XCTAssertEqual(e?.command, "make test")
        XCTAssertEqual(e?.cwd, "/tmp")
        XCTAssertEqual(e?.exitCode, 2)
        XCTAssertEqual(e?.duration ?? 0, 3, accuracy: 0.001)
        XCTAssertNil(t.commandFinished(exitCode: 0))
    }

    func testParsers() {
        XCTAssertEqual(ShellIntegration.parseExit("D;130"), 130)
        XCTAssertEqual(ShellIntegration.parseExit("0"), 0)
        XCTAssertNil(ShellIntegration.parseExit("D;x"))
        XCTAssertEqual(ShellIntegration.decodeBase64("bHMgLWxh"), "ls -la")
    }

    func testLaunchSpec() {
        let dir = URL(fileURLWithPath: "/x")
        let z = ShellIntegration.launchSpec(shell: "/bin/zsh", cwd: "/w", baseEnv: ["HOME": "/h"], integrationDir: dir)
        XCTAssertEqual(z.env["ZDOTDIR"], "/x/zsh")
        XCTAssertEqual(z.env["BT_USER_ZDOTDIR"], "/h")
        XCTAssertEqual(z.env["BT_START_DIR"], "/w")
        let b = ShellIntegration.launchSpec(shell: "/opt/homebrew/bin/bash", cwd: "/w", baseEnv: [:], integrationDir: dir)
        XCTAssertEqual(b.args, ["--rcfile", "/x/bash/bashrc.sh"])
        XCTAssertEqual(ShellIntegration.kind(forShellPath: "/usr/local/bin/fish"), .fish)
    }

    func testInstallWritesScripts() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try ShellIntegration.install(into: dir)
        let z = try String(contentsOf: dir.appendingPathComponent("zsh/.zshrc"), encoding: .utf8)
        XCTAssertTrue(z.contains("7777"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("fish/bt.fish").path))
    }
}
