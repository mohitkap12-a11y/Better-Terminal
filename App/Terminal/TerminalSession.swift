import AppKit
import SwiftUI
import SwiftTerm
import BetterTerminalCore

/// Backend-agnostic handle to a running terminal. Today: SwiftTerm.
/// libghostty can replace the implementation without touching the UI (see ARCHITECTURE.md).
protocol TerminalSession: AnyObject {
    var nsView: NSView { get }
    /// Gives this terminal the keyboard. Returns false when it could not (for example its view is not in a window yet).
    @discardableResult func focus() -> Bool
    /// True when this terminal is its window's first responder, i.e. typing goes here.
    var hasKeyboardFocus: Bool { get }
    func insert(_ text: String)      // replaces the current prompt line, does not run
    func run(_ text: String)         // replaces the current prompt line and runs
    func apply(theme: Theme, scheme: ColorScheme, fontSize: Double, fontFamily: String)
    func terminate()
    /// Output of the last finished command (best effort), for "Copy Last Output".
    var lastOutput: String? { get }
    /// Search the scrollback; selects and scrolls to the match. Returns false when there is none.
    func find(_ term: String, forward: Bool) -> Bool
    func clearFind()
    /// Keys typed in this terminal, as the bytes the shell receives (used for broadcasting).
    var onInput: ((ArraySlice<UInt8>) -> Void)? { get set }
    /// The user pasted into this terminal.
    var onPaste: (() -> Void)? { get set }
    /// Sends bytes straight to the shell without reporting them to `onInput`.
    func sendRaw(_ data: ArraySlice<UInt8>)
    /// Pastes the clipboard here without reporting it to `onPaste`.
    func replayPaste()
    /// A command is running in the shell right now (not just an idle prompt).
    var hasRunningCommand: Bool { get }
    /// Plain text of the terminal (scrollback + screen), for restoring it after a relaunch.
    func snapshotText() -> String
}

/// Follows an append-only file and reports each complete new line (on the main queue).
final class EventFileTailer {
    private let url: URL
    private let onLine: (String) -> Void
    private var source: DispatchSourceFileSystemObject?
    private var offset: UInt64 = 0
    private var partial = Data()

    init(url: URL, onLine: @escaping (String) -> Void) {
        self.url = url
        self.onLine = onLine
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: nil)   // truncates stale events
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .extend], queue: .main)
        src.setEventHandler { [weak self] in self?.drain() }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    private func drain() {
        guard let h = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? h.close() }
        try? h.seek(toOffset: offset)
        guard let data = try? h.readToEnd(), !data.isEmpty else { return }
        offset += UInt64(data.count)
        partial.append(data)
        while let nl = partial.firstIndex(of: 0x0A) {
            let line = String(decoding: partial[partial.startIndex..<nl], as: UTF8.self)
            partial.removeSubrange(partial.startIndex...nl)
            onLine(line)
        }
    }

    func stop() {
        source?.cancel(); source = nil
        try? FileManager.default.removeItem(at: url)
    }

    deinit { source?.cancel() }
}

/// The SwiftTerm view. Reports pastes so panes can mirror them (typed keys are caught by an event monitor,
/// because SwiftTerm sends them straight to the shell without calling the delegate).
final class BTTerminalView: LocalProcessTerminalView {
    var onPaste: (() -> Void)?
    /// Called when the view is put into a window (new tab, split, workspace switch...): the moment focus can be given.
    var onAttach: (() -> Void)?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { onAttach?() }
    }
    var mirroring = false
    override func paste(_ sender: Any) {
        super.paste(sender)
        if !mirroring { onPaste?() }
    }
}

enum TerminalMenuAction { case find, splitRight, splitDown, copyLastOutput }

private final class MenuHandler: NSObject {
    let block: () -> Void
    init(_ block: @escaping () -> Void) { self.block = block }
    @objc func fire() { block() }
}

final class SwiftTermSession: NSObject, TerminalSession, LocalProcessTerminalViewDelegate {
    struct Callbacks {
        var onCommand: @MainActor (HistoryEntry) -> Void
        var onCwd: @MainActor (String) -> Void
        var onTitle: @MainActor (String) -> Void
        var onExit: @MainActor (Int32?) -> Void
        var onFocus: @MainActor () -> Void
        var onRunning: @MainActor (Bool) -> Void = { _ in }
        /// The shell finished its start-up files and showed its first prompt.
        var onReady: @MainActor () -> Void = {}
        /// The terminal's view just joined a window.
        var onAttach: @MainActor () -> Void = {}
        /// Right-click on selected text copies it straight away instead of showing the menu.
        var rightClickCopies: @MainActor () -> Bool = { false }
        /// An item of the terminal's right-click menu that the app handles (find, split, copy output).
        var onMenu: @MainActor (TerminalMenuAction) -> Void = { _ in }
    }

    private let view = BTTerminalView(frame: .zero)
    private var clickMonitor: Any?
    private var rightClickMonitor: Any?
    private var tailer: EventFileTailer?
    private var tracker: CommandTracker
    private let callbacks: Callbacks
    private let shellKind: ShellIntegration.Kind
    var nsView: NSView { view }
    var hasRunningCommand: Bool { tracker.isRunning }
    private var appliedKey: String?
    private var hadCustomColors = false
    private var outputStart = 0
    private var ready = false
    private(set) var lastOutput: String?
    var onInput: ((ArraySlice<UInt8>) -> Void)?
    var onPaste: (() -> Void)? {
        get { view.onPaste }
        set { view.onPaste = newValue }
    }
    private var keyMonitor: Any?
    private var menuHandlers: [MenuHandler] = []

    init(tab: TerminalTab, integrationDir: URL, eventFile: URL, restoredText: String? = nil, callbacks: Callbacks) {
        self.tracker = CommandTracker(cwd: tab.cwd)
        self.callbacks = callbacks
        self.shellKind = ShellIntegration.kind(forShellPath: tab.shell)
        super.init()
        view.processDelegate = self
        view.onAttach = { Task { @MainActor in callbacks.onAttach() } }
        view.changeScrollback(5000)
        // Show what was on screen last time, then a fresh shell starts below it.
        if let saved = restoredText {
            let payload = TerminalText.replayPayload(saved)
            if !payload.isEmpty { view.feed(text: payload) }
        }

        // LocalProcessTerminalView's responder methods are not `open`, so detect focus via clicks.
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            if let v = self?.view, let w = v.window, event.window === w,
               v.bounds.contains(v.convert(event.locationInWindow, from: nil)) {
                Task { @MainActor in callbacks.onFocus() }
            }
            return event
        }

        // Right-click: a context menu (copy, paste, select all, open link, find, split, clear),
        // or copy straight away when the setting says so and text is selected.
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard let self, let w = self.view.window, event.window === w,
                  self.view.bounds.contains(self.view.convert(event.locationInWindow, from: nil)) else { return event }
            // Right-clicking a pane selects it, like a left click: it becomes the active pane and takes the keyboard,
            // so Paste (or ⌘V afterwards) goes here and not to the pane you were in before.
            Task { @MainActor in callbacks.onFocus() }
            w.makeFirstResponder(self.view)
            if self.view.selectionActive, MainActor.assumeIsolated({ callbacks.rightClickCopies() }) {
                self.view.copy(self)
                return nil
            }
            self.showContextMenu(for: event)
            return nil
        }

        // Typed keys, for broadcasting to other panes. Only while this terminal has the keyboard.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Monitors see every key in the app, so also require the event to belong to this terminal's window
            // (typing in the quick terminal must not reach the main window's panes).
            guard let self, let handler = self.onInput, let window = self.view.window, event.window === window,
                  window.firstResponder === self.view,
                  let bytes = KeyBytes.bytes(for: event) else { return event }
            handler(bytes[...])
            return event
        }

        // Underline links when hovered; click one to open it.
        view.linkHighlightMode = .hover

        tailer = EventFileTailer(url: eventFile) { [weak self] line in self?.handle(line) }

        try? ShellIntegration.install(into: integrationDir)
        let spec = ShellIntegration.launchSpec(shell: tab.shell, cwd: tab.cwd,
                                               baseEnv: ProcessInfo.processInfo.environment,
                                               integrationDir: integrationDir,
                                               eventFile: eventFile.path)
        let envArray = spec.env.map { "\($0.key)=\($0.value)" }
        view.startProcess(executable: tab.shell, args: spec.args, environment: envArray, execName: nil)
    }

    private func handle(_ line: String) {
        switch ShellEvent.parse(line) {
        case .commandStarted(let cmd)?:
            tracker.commandStarted(cmd)
            outputStart = snapshotText().count
            Task { @MainActor in callbacks.onRunning(true) }
        case .commandFinished(let code)?:
            if let o = CommandOutput.since(snapshotText(), startLength: outputStart) { lastOutput = o }
            if let entry = tracker.commandFinished(exitCode: code) {
                Task { @MainActor in callbacks.onCommand(entry) }
            }
            Task { @MainActor in callbacks.onRunning(false) }
        case .cwd(let cwd)?:
            if !ready { ready = true; Task { @MainActor in callbacks.onReady() } }
            tracker.cwd = cwd
            Task { @MainActor in callbacks.onCwd(cwd) }
        case nil:
            break
        }
    }

    // zsh and fish enable bracketed paste by default; bash 3.2 (macOS) does not.
    private var bracketedPaste: Bool { shellKind == .zsh || shellKind == .fish }

    // MARK: TerminalSession
    @discardableResult func focus() -> Bool {
        guard let w = view.window else { return false }
        if w.firstResponder === view { return true }
        return w.makeFirstResponder(view)
    }

    var hasKeyboardFocus: Bool { view.window?.firstResponder === view }

    func insert(_ text: String) {
        view.send(txt: PromptInput.insertPayload(text, bracketedPaste: bracketedPaste))
    }

    func run(_ text: String) {
        view.send(txt: PromptInput.runPayload(text, bracketedPaste: bracketedPaste))
    }

    func apply(theme: Theme, scheme: ColorScheme, fontSize: Double, fontFamily: String) {
        // Re-applying identical colors/fonts makes the terminal redraw fully; skip when nothing changed.
        let key = "\(theme.id)|\(theme.background(scheme))|\(scheme == .dark)|\(fontSize)|\(fontFamily)"
        guard key != appliedKey else { return }
        appliedKey = key
        if let ansi = theme.ansi, ansi.count == 16 {
            view.installColors(ansi.map { hex in
                let (r, g, b) = ThemeImport.rgb(hex) ?? (0, 0, 0)
                return SwiftTerm.Color(red: UInt16(r * 65535), green: UInt16(g * 65535), blue: UInt16(b * 65535))
            })
            hadCustomColors = true
        } else if hadCustomColors {
            view.installColors(SwiftTerm.Color.defaultInstalledColors)
            hadCustomColors = false
        }
        view.nativeBackgroundColor = NSColor(theme.terminalBackground(scheme))
        view.nativeForegroundColor = NSColor(theme.terminalForeground(scheme))
        let custom = fontFamily.isEmpty ? nil : NSFont(name: fontFamily, size: CGFloat(fontSize))
        let f = custom ?? NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        if view.font.pointSize != f.pointSize || view.font.fontName != f.fontName { view.font = f }
    }

    func find(_ term: String, forward: Bool) -> Bool {
        guard !term.isEmpty else { view.clearSearch(); return false }
        return forward ? view.findNext(term) : view.findPrevious(term)
    }

    func clearFind() { view.clearSearch() }

    func sendRaw(_ data: ArraySlice<UInt8>) { view.process?.send(data: data) }

    func replayPaste() {
        view.mirroring = true
        view.paste(self)
        view.mirroring = false
    }

    // MARK: Right-click menu

    private static let urlPattern = try? NSRegularExpression(pattern: #"(?:https?|file)://[^\s<>"'`]+"#)

    /// URLs in `text`, trailing punctuation removed, newest (last) first, without duplicates.
    static func urls(in text: String, limit: Int = 8) -> [URL] {
        guard let re = urlPattern else { return [] }
        let ns = text as NSString
        var seen = Set<String>(), out: [URL] = []
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            var s = ns.substring(with: m.range)
            while let last = s.last, ".,;:!?)]}>".contains(last) { s.removeLast() }
            if seen.insert(s).inserted, let u = URL(string: s) { out.append(u) }
            if out.count == limit { break }
        }
        return out
    }

    private func showContextMenu(for event: NSEvent) {
        let menu = NSMenu()
        menuHandlers = []
        func add(_ title: String, key: String = "", enabled: Bool = true, _ block: @escaping () -> Void) {
            let h = MenuHandler(block)
            menuHandlers.append(h)
            let item = NSMenuItem(title: title, action: #selector(MenuHandler.fire), keyEquivalent: key)
            item.target = h
            item.isEnabled = enabled
            menu.addItem(item)
        }
        let hasSelection = view.selectionActive
        add("Copy", key: "c", enabled: hasSelection) { [weak self] in
            if let v = self?.view { v.copy(v) }
        }
        add("Paste", key: "v") { [weak self] in
            if let v = self?.view { v.paste(v) }
        }
        add("Select All", key: "a") { [weak self] in self?.view.selectAll() }

        // Links: the selection if it is one, otherwise the URLs on screen.
        var links: [URL] = []
        if hasSelection, let sel = view.getSelection(), let u = Self.urls(in: sel, limit: 1).first { links = [u] }
        if links.isEmpty { links = Self.urls(in: String(snapshotText().suffix(8000))) }
        if links.count == 1, let url = links.first {
            menu.addItem(.separator())
            add("Open \(url.host ?? url.absoluteString)…") { NSWorkspace.shared.open(url) }
        } else if links.count > 1 {
            menu.addItem(.separator())
            let sub = NSMenu()
            for url in links {
                let h = MenuHandler { NSWorkspace.shared.open(url) }
                menuHandlers.append(h)
                let item = NSMenuItem(title: url.absoluteString.count > 60 ? String(url.absoluteString.prefix(57)) + "…" : url.absoluteString,
                                      action: #selector(MenuHandler.fire), keyEquivalent: "")
                item.target = h
                sub.addItem(item)
            }
            let parent = NSMenuItem(title: "Open Link", action: nil, keyEquivalent: "")
            parent.submenu = sub
            menu.addItem(parent)
        }

        menu.addItem(.separator())
        add("Find…", key: "f") { [callbacks = self.callbacks] in Task { @MainActor in callbacks.onMenu(.find) } }
        add("Split Right") { [callbacks = self.callbacks] in Task { @MainActor in callbacks.onMenu(.splitRight) } }
        add("Split Down") { [callbacks = self.callbacks] in Task { @MainActor in callbacks.onMenu(.splitDown) } }
        add("Copy Last Command Output", enabled: lastOutput != nil) { [callbacks = self.callbacks] in Task { @MainActor in callbacks.onMenu(.copyLastOutput) } }
        add("Clear Screen") { [weak self] in self?.view.send(txt: "\u{0C}") }
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    func snapshotText() -> String {
        String(decoding: view.getBufferAsData(kind: .normal), as: UTF8.self)
    }

    func terminate() {
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        if let m = rightClickMonitor { NSEvent.removeMonitor(m); rightClickMonitor = nil }
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        tailer?.stop(); tailer = nil
        view.terminate()
    }

    deinit {
        if let m = clickMonitor { NSEvent.removeMonitor(m) }
        if let m = rightClickMonitor { NSEvent.removeMonitor(m) }
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
    }

    // MARK: LocalProcessTerminalViewDelegate
    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        Task { @MainActor in callbacks.onTitle(title) }
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor in callbacks.onExit(exitCode) }
    }
}

struct TerminalHost: NSViewRepresentable {
    let session: TerminalSession
    let theme: Theme
    let scheme: ColorScheme
    let fontSize: Double
    var fontFamily: String = ""

    func makeNSView(context: Context) -> NSView {
        session.apply(theme: theme, scheme: scheme, fontSize: fontSize, fontFamily: fontFamily)
        return session.nsView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        session.apply(theme: theme, scheme: scheme, fontSize: fontSize, fontFamily: fontFamily)
    }
}
