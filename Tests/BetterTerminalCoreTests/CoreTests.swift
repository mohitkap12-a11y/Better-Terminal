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

final class ReorderTests: XCTestCase {
    private func state() -> (AppState, [UUID], [UUID]) {
        var a = Workspace(name: "A"); var b = Workspace(name: "B"); var c = Workspace(name: "C")
        a.addTab(); a.addTab(); b.addTab(); c.addTab()
        let st = AppState(workspaces: [a, b, c])
        return (st, st.workspaces.map(\.id), st.workspaces.flatMap { $0.tabs.map(\.id) })
    }

    func testMoveWorkspace() {
        var (s, w, _) = state()
        XCTAssertTrue(s.moveWorkspace(w[2], before: w[0]))
        XCTAssertEqual(s.workspaces.map(\.name), ["C", "A", "B"])
        XCTAssertTrue(s.moveWorkspace(w[2], before: nil))
        XCTAssertEqual(s.workspaces.map(\.name), ["A", "B", "C"])
        XCTAssertFalse(s.moveWorkspace(w[0], before: w[0]))
        XCTAssertFalse(s.moveWorkspace(w[0], before: UUID()))
        XCTAssertEqual(s.workspaces.map(\.name), ["A", "B", "C"])
    }

    func testReorderTabsWithinWorkspace() {
        var (s, w, t) = state()                      // A has t[0], t[1]
        XCTAssertTrue(s.moveTab(t[1], toWorkspace: w[0], before: t[0]))
        XCTAssertEqual(s.workspaces[0].tabs.map(\.id), [t[1], t[0]])
        XCTAssertEqual(s.workspaces[0].activeTabID, t[1])
    }

    func testMoveTabAcrossWorkspaces() {
        var (s, w, t) = state()
        XCTAssertTrue(s.moveTab(t[0], toWorkspace: w[1]))
        XCTAssertEqual(s.workspaces[0].tabs.map(\.id), [t[1]])
        XCTAssertEqual(s.workspaces[1].tabs.map(\.id), [t[2], t[0]])
        XCTAssertEqual(s.workspaces[1].activeTabID, t[0])
        XCTAssertEqual(s.workspaces[0].activeTabID, t[1])    // source picks a neighbour
    }

    func testMovingLastTabLeavesAFreshOne() {
        var (s, w, t) = state()
        XCTAssertTrue(s.moveTab(t[2], toWorkspace: w[0]))      // B's only tab
        XCTAssertEqual(s.workspaces[1].tabs.count, 1)
        XCTAssertNotEqual(s.workspaces[1].tabs[0].id, t[2])
        XCTAssertEqual(s.workspaces[1].activeTabID, s.workspaces[1].tabs[0].id)
        XCTAssertEqual(s.workspaces[0].tabs.count, 3)
    }

    func testReorderOnlyTabIsNoOp() {
        var (s, w, t) = state()
        XCTAssertTrue(s.moveTab(t[2], toWorkspace: w[1]))      // B's only tab, same workspace
        XCTAssertEqual(s.workspaces[1].tabs.map(\.id), [t[2]])
    }

    func testMoveRejectsBadInput() {
        var (s, w, t) = state()
        XCTAssertFalse(s.moveTab(UUID(), toWorkspace: w[0]))
        XCTAssertFalse(s.moveTab(t[0], toWorkspace: UUID()))
        XCTAssertFalse(s.moveTab(t[0], toWorkspace: w[1], before: UUID()))
        XCTAssertFalse(s.moveTab(t[0], toWorkspace: w[0], before: t[0]))
    }

    func testRenameTab() throws {
        var (s, _, t) = state()
        XCTAssertTrue(s.renameTab(t[0], to: "  server  "))
        XCTAssertEqual(s.workspaces[0].tabs[0].title, "server")
        XCTAssertTrue(s.workspaces[0].tabs[0].hasCustomTitle)
        s.workspaces[0].tabs[0].shellTitle = "vim notes.md"     // the shell kept reporting its title
        XCTAssertTrue(s.renameTab(t[0], to: "   "))          // empty: back to shell titles
        XCTAssertFalse(s.workspaces[0].tabs[0].hasCustomTitle)
        XCTAssertEqual(s.workspaces[0].tabs[0].title, "vim notes.md")
        XCTAssertFalse(s.renameTab(UUID(), to: "x"))
    }

    func testOldTabsWithoutCustomTitleStillDecode() throws {
        let json = #"{"id":"11111111-1111-1111-1111-111111111111","title":"T","cwd":"/","shell":"/bin/zsh"}"#
        let tab = try JSONDecoder().decode(TerminalTab.self, from: Data(json.utf8))
        XCTAssertFalse(tab.hasCustomTitle)
        XCTAssertEqual(tab.shellTitle, "T")
    }
}


final class EffectiveLayoutTests: XCTestCase {
    func testShrinksAlongLongSide() {
        let l = PaneLayout(rows: 1, columns: 6)
        XCTAssertEqual(l.effective(forPaneCount: 6), l)
        XCTAssertEqual(l.effective(forPaneCount: 5), PaneLayout(rows: 1, columns: 5))
        XCTAssertEqual(l.effective(forPaneCount: 2), PaneLayout(rows: 1, columns: 2))
        XCTAssertEqual(l.effective(forPaneCount: 1), PaneLayout(rows: 1, columns: 1))
        let v = PaneLayout(rows: 6, columns: 1)
        XCTAssertEqual(v.effective(forPaneCount: 3), PaneLayout(rows: 3, columns: 1))
    }

    func testGridShrinksAndNeverHidesPanes() {
        let g = PaneLayout(rows: 3, columns: 3)
        XCTAssertEqual(g.effective(forPaneCount: 4), PaneLayout(rows: 2, columns: 3))
        XCTAssertEqual(g.effective(forPaneCount: 2), PaneLayout(rows: 1, columns: 2))
        XCTAssertEqual(PaneLayout(rows: 2, columns: 2).effective(forPaneCount: 3), PaneLayout(rows: 2, columns: 2))
        for layout in PaneLayout.presets {
            for n in 1...12 {
                let e = layout.effective(forPaneCount: n)
                XCTAssertGreaterThanOrEqual(max(e.capacity, e.columns * e.rowsNeeded(forPaneCount: n)), n)
            }
        }
    }

    func testTrackerReportsRunning() {
        var t = CommandTracker(cwd: "/")
        XCTAssertFalse(t.isRunning)
        t.commandStarted("sleep 5")
        XCTAssertTrue(t.isRunning)
        _ = t.commandFinished(exitCode: 0)
        XCTAssertFalse(t.isRunning)
    }

    func testConfirmCloseDefaultsOnForOldState() throws {
        let old = #"{"workspaces":[]}"#.data(using: .utf8)!
        XCTAssertTrue(try JSONDecoder().decode(AppState.self, from: old).confirmCloseRunning)
    }
}


final class BatchFeatureTests: XCTestCase {
    func testSplitRightGrowsColumnsAndInsertsAfterActive() {
        var ws = Workspace(name: "w"); ws.addTab(); ws.addTab()           // 1x1 layout, 2 tabs, last active
        ws.activeTabID = ws.tabs[0].id
        let t = ws.split(.right)
        XCTAssertEqual(ws.tabs[1].id, t.id)
        XCTAssertEqual(ws.activeTabID, t.id)
        XCTAssertEqual(ws.layout, PaneLayout(rows: 1, columns: 3))
    }

    func testSplitDownFromSinglePane() {
        var ws = Workspace(name: "w"); ws.addTab()
        ws.split(.down)
        XCTAssertEqual(ws.layout, PaneLayout(rows: 2, columns: 1))
        ws.split(.right)                                                  // 2x1 + 3rd tab -> grid grows
        XCTAssertGreaterThanOrEqual(ws.layout.capacity, 3)
    }

    func testGrowingNeverExceedsMax() {
        let l = PaneLayout(rows: 6, columns: 6)
        XCTAssertEqual(l.growing(toFit: 40, along: .right), l)
    }

    func testSwapTabs() {
        var s = AppState.fresh()
        s.workspaces[0].addTab(); s.workspaces[0].addTab()
        let ids = s.workspaces[0].tabs.map(\.id)
        XCTAssertTrue(s.swapTabs(ids[0], ids[2]))
        XCTAssertEqual(s.workspaces[0].tabs.map(\.id), [ids[2], ids[1], ids[0]])
        XCTAssertFalse(s.swapTabs(ids[0], ids[0]))
    }

    func testTemplateRoundTrip() {
        var ws = Workspace(name: "Dev", layout: PaneLayout(rows: 1, columns: 2)); ws.addTab(cwd: "/a"); ws.addTab(cwd: "/b")
        var tpl = ws.asTemplate(named: "Dev setup")
        tpl.tabs[1].command = "npm run dev"
        let made = tpl.makeWorkspace(colorHex: "#FFFFFF")
        XCTAssertEqual(made.tabs.map(\.cwd), ["/a", "/b"])
        XCTAssertNil(made.tabs[0].startupCommand)
        XCTAssertEqual(made.tabs[1].startupCommand, "npm run dev")
        XCTAssertEqual(made.layout, ws.layout)
        XCTAssertNotEqual(made.id, ws.id)
    }

    func testOldStateStillDecodes() throws {
        let json = #"{"workspaces":[{"id":"\#(UUID().uuidString)","name":"A","colorHex":"x","layout":{"rows":1,"columns":1},"tabs":[]}]}"#
        let s = try JSONDecoder().decode(AppState.self, from: json.data(using: .utf8)!)
        XCTAssertFalse(s.workspaces[0].broadcast)
        XCTAssertTrue(s.templates.isEmpty)
        XCTAssertEqual(s.terminalFontFamily, "")
        XCTAssertTrue(s.notifyLongCommands)
    }

    func testHexNormalizing() {
        XCTAssertEqual(ThemeImport.normalizeHex("#abc"), "#AABBCC")
        XCTAssertEqual(ThemeImport.normalizeHex("0x1e1e2e"), "#1E1E2E")
        XCTAssertEqual(ThemeImport.normalizeHex("rgb:ff/00/80"), "#FF0080")
        XCTAssertNil(ThemeImport.normalizeHex("zzz"))
    }

    func testParseGhosttyStyle() {
        let text = """
        # comment
        background = #1e1e2e
        foreground = cdd6f4
        palette = 0=#45475a
        palette = 4=#89b4fa
        """
        let t = ThemeImport.parseKeyValue(text, name: "Mocha")
        XCTAssertEqual(t?.background, "#1E1E2E")
        XCTAssertEqual(t?.foreground, "#CDD6F4")
        XCTAssertEqual(t?.accent, "#89B4FA")
        XCTAssertEqual(t?.isDark, true)
        XCTAssertNil(ThemeImport.parseKeyValue("nothing here", name: "x"))
    }

    func testParseKittyStyle() {
        let t = ThemeImport.parseKeyValue("background #ffffff\nforeground #000000\ncolor4 #0000ff", name: "Light")
        XCTAssertEqual(t?.accent, "#0000FF")
        XCTAssertEqual(t?.isDark, false)
    }

    func testParseITerm() {
        func comp(_ r: Double, _ g: Double, _ b: Double) -> String {
            "<dict><key>Red Component</key><real>\(r)</real><key>Green Component</key><real>\(g)</real><key>Blue Component</key><real>\(b)</real></dict>"
        }
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
        <key>Background Color</key>\(comp(0, 0, 0))
        <key>Foreground Color</key>\(comp(1, 1, 1))
        </dict></plist>
        """
        let t = ThemeImport.parse(xml.data(using: .utf8)!, name: "Black")
        XCTAssertEqual(t?.background, "#000000")
        XCTAssertEqual(t?.foreground, "#FFFFFF")
    }

    func testShift() {
        XCTAssertEqual(ThemeImport.shifted("#000000", by: 0.5), "#808080")
        XCTAssertEqual(ThemeImport.shifted("#FFFFFF", by: -1), "#000000")
    }

    func testCommandOutput() {
        XCTAssertEqual(CommandOutput.since("$ ls\nfile1\nfile2\n", startLength: 5), "file1\nfile2")
        XCTAssertNil(CommandOutput.since("short", startLength: 50))
        XCTAssertNil(CommandOutput.since("abc", startLength: 3))
    }

    func testSavedCommands() {
        var st = AppState.fresh()
        XCTAssertTrue(st.saveCommand("  git pull --rebase \n"))
        XCTAssertFalse(st.saveCommand("git pull --rebase"), "duplicates are ignored")
        XCTAssertFalse(st.saveCommand("   "), "empty commands are ignored")
        XCTAssertEqual(st.savedCommands.map(\.command), ["git pull --rebase"])
        XCTAssertTrue(st.isSaved(" git pull --rebase"))

        st.saveCommand("./deploy.sh --env=staging", name: " Deploy staging ")
        XCTAssertEqual(st.savedCommands[1].name, "Deploy staging")
        XCTAssertEqual(st.savedCommands[1].title, "Deploy staging")
        XCTAssertEqual(st.savedCommands[0].title, "git pull --rebase")

        XCTAssertEqual(st.searchSavedCommands("deploy").count, 1)
        XCTAssertEqual(st.searchSavedCommands("STAGING").count, 1)
        XCTAssertEqual(st.searchSavedCommands("").count, 2)

        st.moveSavedCommand(st.savedCommands[1].id, by: -1)
        XCTAssertEqual(st.savedCommands.first?.name, "Deploy staging")
        st.moveSavedCommand(st.savedCommands[0].id, by: -5)
        XCTAssertEqual(st.savedCommands.first?.name, "Deploy staging", "clamped at the top")

        XCTAssertFalse(st.toggleSaved("git pull --rebase"))
        XCTAssertFalse(st.isSaved("git pull --rebase"))
        XCTAssertTrue(st.toggleSaved("git pull --rebase"))
        XCTAssertEqual(st.savedCommands.count, 2)
    }

    func testSavedCommandsDecodeFromOldState() throws {
        let old = #"{"version":2,"workspaces":[]}"#
        let st = try JSONDecoder().decode(AppState.self, from: Data(old.utf8))
        XCTAssertTrue(st.savedCommands.isEmpty)

        var withSaved = AppState()
        withSaved.saveCommand("ls -la", name: "List")
        let back = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(withSaved))
        XCTAssertEqual(back.savedCommands, withSaved.savedCommands)
    }
}
