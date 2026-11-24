import AppKit
import SwiftUI
import SwiftTerm
import BetterTerminalCore

/// Backend-agnostic handle to a running terminal. Today: SwiftTerm.
/// libghostty can replace the implementation without touching the UI (see ARCHITECTURE.md).
protocol TerminalSession: AnyObject {
    var nsView: NSView { get }
    func focus()
    func insert(_ text: String)      // replaces the current prompt line, does not run
    func run(_ text: String)         // replaces the current prompt line and runs
    func apply(theme: Theme, scheme: ColorScheme, fontSize: Double)
    func terminate()
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

final class SwiftTermSession: NSObject, TerminalSession, LocalProcessTerminalViewDelegate {
    struct Callbacks {
        var onCommand: @MainActor (HistoryEntry) -> Void
        var onCwd: @MainActor (String) -> Void
        var onTitle: @MainActor (String) -> Void
        var onExit: @MainActor (Int32?) -> Void
        var onFocus: @MainActor () -> Void
    }

    private let view = LocalProcessTerminalView(frame: .zero)
    private var clickMonitor: Any?
    private var rightClickMonitor: Any?
    private var tailer: EventFileTailer?
    private var tracker: CommandTracker
    private let callbacks: Callbacks
    private let shellKind: ShellIntegration.Kind
    var nsView: NSView { view }
    var hasRunningCommand: Bool { tracker.isRunning }
    private var appliedKey: String?

    init(tab: TerminalTab, integrationDir: URL, eventFile: URL, restoredText: String? = nil, callbacks: Callbacks) {
        self.tracker = CommandTracker(cwd: tab.cwd)
        self.callbacks = callbacks
        self.shellKind = ShellIntegration.kind(forShellPath: tab.shell)
        super.init()
        view.processDelegate = self
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

        // Right-click on selected text copies it (instead of opening a menu).
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard let self, let w = self.view.window, event.window === w,
                  self.view.bounds.contains(self.view.convert(event.locationInWindow, from: nil)),
                  self.view.selectionActive else { return event }
            self.view.copy(self)
            return nil
        }

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
        case .commandFinished(let code)?:
            if let entry = tracker.commandFinished(exitCode: code) {
                Task { @MainActor in callbacks.onCommand(entry) }
            }
        case .cwd(let cwd)?:
            tracker.cwd = cwd
            Task { @MainActor in callbacks.onCwd(cwd) }
        case nil:
            break
        }
    }

    // zsh and fish enable bracketed paste by default; bash 3.2 (macOS) does not.
    private var bracketedPaste: Bool { shellKind == .zsh || shellKind == .fish }

    // MARK: TerminalSession
    func focus() { view.window?.makeFirstResponder(view) }

    func insert(_ text: String) {
        view.send(txt: PromptInput.insertPayload(text, bracketedPaste: bracketedPaste))
    }

    func run(_ text: String) {
        view.send(txt: PromptInput.runPayload(text, bracketedPaste: bracketedPaste))
    }

    func apply(theme: Theme, scheme: ColorScheme, fontSize: Double) {
        // Re-applying identical colors/fonts makes the terminal redraw fully; skip when nothing changed.
        let key = "\(theme.id)|\(scheme == .dark)|\(fontSize)"
        guard key != appliedKey else { return }
        appliedKey = key
        view.nativeBackgroundColor = NSColor(theme.terminalBackground(scheme))
        view.nativeForegroundColor = NSColor(theme.terminalForeground(scheme))
        let f = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        if view.font.pointSize != f.pointSize { view.font = f }
    }

    func snapshotText() -> String {
        String(decoding: view.getBufferAsData(kind: .normal), as: UTF8.self)
    }

    func terminate() {
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        if let m = rightClickMonitor { NSEvent.removeMonitor(m); rightClickMonitor = nil }
        tailer?.stop(); tailer = nil
        view.terminate()
    }

    deinit {
        if let m = clickMonitor { NSEvent.removeMonitor(m) }
        if let m = rightClickMonitor { NSEvent.removeMonitor(m) }
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

    func makeNSView(context: Context) -> NSView {
        session.apply(theme: theme, scheme: scheme, fontSize: fontSize)
        return session.nsView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        session.apply(theme: theme, scheme: scheme, fontSize: fontSize)
    }
}
