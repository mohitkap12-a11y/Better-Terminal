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
        ["terminalFontSize", "version"].forEach { obj.removeValue(forKey: $0) }
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
        XCTAssertTrue(z.contains("BT_EVENT_FILE"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("fish/bt.fish").path))
    }
}

final class ReviewFixTests: XCTestCase {
    func testFishPathWithSpacesIsQuoted() {
        let dir = URL(fileURLWithPath: "/Users/me/Library/Application Support/BetterTerminal/shell-integration")
        let spec = ShellIntegration.launchSpec(shell: "/opt/homebrew/bin/fish", cwd: "/", baseEnv: [:], integrationDir: dir)
        XCTAssertEqual(spec.args[1], "source '/Users/me/Library/Application Support/BetterTerminal/shell-integration/fish/bt.fish'")
        XCTAssertEqual(ShellIntegration.fishQuote("it's"), "'it\\'s'")
    }

    func testMultilineInsertNeverSendsRawNewlineOutsidePaste() {
        let p = PromptInput.insertPayload("echo a\necho b", bracketedPaste: true)
        XCTAssertEqual(p, "\u{15}\u{1B}[200~echo a\necho b\u{1B}[201~")
        let q = PromptInput.insertPayload("echo a\necho b", bracketedPaste: false)
        XCTAssertFalse(q.contains("\n"))
        XCTAssertFalse(q.contains("\r"))
        XCTAssertEqual(q, "\u{15}echo a; echo b")
    }

    func testSanitizeStripsEscapeAndCR() {
        XCTAssertEqual(PromptInput.sanitize("ls\u{1B}[201~; rm x\r\n"), "ls[201~; rm x\n")
        XCTAssertEqual(PromptInput.insertPayload("ls\r", bracketedPaste: false), "\u{15}ls")
    }

    func testRunAppendsEnterOnce() {
        XCTAssertEqual(PromptInput.runPayload("ls", bracketedPaste: true), "\u{15}ls\r")
    }
}

final class EventTests: XCTestCase {
    func testParseEvents() {
        XCTAssertEqual(ShellEvent.parse("S\tbHMgLWxh"), .commandStarted("ls -la"))
        XCTAssertEqual(ShellEvent.parse("D\t127"), .commandFinished(127))
        XCTAssertEqual(ShellEvent.parse("C\tL3RtcA=="), .cwd("/tmp"))
        XCTAssertNil(ShellEvent.parse("garbage"))
        XCTAssertNil(ShellEvent.parse("X\t1"))
    }

    func testLaunchSpecSetsEventFile() {
        let s = ShellIntegration.launchSpec(shell: "/bin/zsh", cwd: "/", baseEnv: [:],
                                            integrationDir: URL(fileURLWithPath: "/x"), eventFile: "/e/1.log")
        XCTAssertEqual(s.env["BT_EVENT_FILE"], "/e/1.log")
    }
}

final class PaneNavigationTests: XCTestCase {
    func testMovesInGrid() {
        let l = PaneLayout(rows: 2, columns: 3)           // panes 0 1 2 / 3 4 5
        XCTAssertEqual(l.neighbor(of: 0, .right, paneCount: 6), 1)
        XCTAssertEqual(l.neighbor(of: 2, .right, paneCount: 6), nil)
        XCTAssertEqual(l.neighbor(of: 4, .left, paneCount: 6), 3)
        XCTAssertEqual(l.neighbor(of: 3, .left, paneCount: 6), nil)
        XCTAssertEqual(l.neighbor(of: 1, .down, paneCount: 6), 4)
        XCTAssertEqual(l.neighbor(of: 4, .up, paneCount: 6), 1)
        XCTAssertEqual(l.neighbor(of: 1, .up, paneCount: 6), nil)
        XCTAssertEqual(l.neighbor(of: 4, .down, paneCount: 6), nil)
    }

    func testShortLastRow() {
        let l = PaneLayout(rows: 2, columns: 3)           // 0 1 2 / 3 4 and an empty cell
        XCTAssertEqual(l.neighbor(of: 4, .right, paneCount: 5), nil)
        XCTAssertEqual(l.neighbor(of: 2, .down, paneCount: 5), 4)   // lands on the row's last pane
        XCTAssertEqual(l.neighbor(of: 1, .down, paneCount: 5), 4)
    }

    func testSinglePaneAndInvalid() {
        let l = PaneLayout.single
        XCTAssertNil(l.neighbor(of: 0, .down, paneCount: 1))
        XCTAssertNil(l.neighbor(of: 3, .left, paneCount: 1))
        // more tabs than the layout holds: extra rows are reachable
        XCTAssertEqual(PaneLayout(rows: 1, columns: 2).neighbor(of: 0, .down, paneCount: 4), 2)
    }
}

final class SnapshotTests: XCTestCase {
    func testPrepareTrimsAndCleans() {
        let raw = "$ ls   \r\nfile\u{1B}[31m\r\n\r\n\r\n"
        XCTAssertEqual(TerminalText.prepare(raw), "$ ls\nfile[31m")
        XCTAssertEqual(TerminalText.prepare("\n\n  \n"), "")
    }

    func testPrepareKeepsLastLines() {
        let raw = (1...10).map { "l\($0)" }.joined(separator: "\n")
        XCTAssertEqual(TerminalText.prepare(raw, maxLines: 3), "l8\nl9\nl10")
    }

    func testReplayPayload() {
        XCTAssertEqual(TerminalText.replayPayload(""), "")
        let p = TerminalText.replayPayload("a\nb")
        XCTAssertTrue(p.hasPrefix("a\r\nb\r\n"))
        XCTAssertTrue(p.contains("restored from previous session"))
        XCTAssertFalse(p.contains("\n\n"))
    }

    func testSnapshotsSurviveRelaunchAndClear() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let s1 = try WorkspaceStore(directory: dir)
        let a = UUID(), b = UUID()
        try s1.saveSnapshot("hello", tab: a)
        try s1.saveSnapshot("world", tab: b)
        let s2 = try WorkspaceStore(directory: dir)
        XCTAssertEqual(s2.loadSnapshot(tab: a), "hello")
        s2.deleteSnapshot(tab: a)
        XCTAssertNil(s2.loadSnapshot(tab: a))
        try s2.saveSnapshot("", tab: b)                    // empty removes
        XCTAssertNil(s2.loadSnapshot(tab: b))
        try s2.saveSnapshot("x", tab: b)
        s2.clearSnapshots()
        XCTAssertNil(s2.loadSnapshot(tab: b))
    }

    func testRestoreSettingDefaultsOn() throws {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        var obj = try JSONSerialization.jsonObject(with: enc.encode(AppState.fresh())) as! [String: Any]
        obj.removeValue(forKey: "restoreTerminalText")
        let s = try JSONDecoder().decode(AppState.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertTrue(s.restoreTerminalText)
    }
}

final class ClearSnapshotTests: XCTestCase {
    func testNothingSavedUntilNewOutput() {
        let base = "$ ls\nfile\n$"
        XCTAssertEqual(TerminalText.afterClear(base, baseline: base), "")
    }

    func testOnlyNewTextIsSaved() {
        let base = "$ ls\nfile\n$"
        let now = "$ ls\nfile\n$ pwd\n/tmp\n$"
        XCTAssertEqual(TerminalText.afterClear(now, baseline: base), "pwd\n/tmp\n$")
    }

    func testNoBaselineKeepsEverything() {
        XCTAssertEqual(TerminalText.afterClear("a\nb", baseline: ""), "a\nb")
    }

    func testScrolledPastBaselineKeepsText() {
        XCTAssertEqual(TerminalText.afterClear("new stuff", baseline: "old stuff"), "new stuff")
    }
}
