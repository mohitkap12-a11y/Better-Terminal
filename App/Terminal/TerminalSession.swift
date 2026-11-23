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
    private var tracker: CommandTracker
    private let callbacks: Callbacks
    var nsView: NSView { view }

    init(tab: TerminalTab, integrationDir: URL, callbacks: Callbacks) {
        self.tracker = CommandTracker(cwd: tab.cwd)
        self.callbacks = callbacks
        super.init()
        view.processDelegate = self
        // LocalProcessTerminalView's responder methods are not `open`, so detect focus via clicks.
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            if let v = self?.view, let w = v.window, event.window === w,
               v.bounds.contains(v.convert(event.locationInWindow, from: nil)) {
                Task { @MainActor in callbacks.onFocus() }
            }
            return event
        }
        installOscHandlers()

        try? ShellIntegration.install(into: integrationDir)
        let spec = ShellIntegration.launchSpec(shell: tab.shell, cwd: tab.cwd,
                                               baseEnv: ProcessInfo.processInfo.environment,
                                               integrationDir: integrationDir)
        let envArray = spec.env.map { "\($0.key)=\($0.value)" }
        view.startProcess(executable: tab.shell, args: spec.args, environment: envArray, execName: nil)
    }

    private func installOscHandlers() {
        let term = view.terminal
        term.registerOscHandler(code: 7777) { [weak self] data in
            guard let self, let cmd = ShellIntegration.decodeBase64(String(decoding: data, as: UTF8.self)) else { return }
            self.tracker.commandStarted(cmd)
        }
        term.registerOscHandler(code: 133) { [weak self] data in
            guard let self else { return }
            let s = String(decoding: data, as: UTF8.self)
            guard s.hasPrefix("D") else { return }
            let code = ShellIntegration.parseExit(s)
            if let entry = self.tracker.commandFinished(exitCode: code) {
                Task { @MainActor in self.callbacks.onCommand(entry) }
            }
        }
        term.registerOscHandler(code: 7779) { [weak self] data in
            guard let self, let cwd = ShellIntegration.decodeBase64(String(decoding: data, as: UTF8.self)) else { return }
            self.tracker.cwd = cwd
            Task { @MainActor in self.callbacks.onCwd(cwd) }
        }
    }

    // MARK: TerminalSession
    func focus() { view.window?.makeFirstResponder(view) }

    func insert(_ text: String) {
        view.send(txt: PromptInput.insertPayload(text, bracketedPaste: view.terminal.bracketedPasteMode))
    }

    func run(_ text: String) {
        view.send(txt: PromptInput.runPayload(text, bracketedPaste: view.terminal.bracketedPasteMode))
    }

    func apply(theme: Theme, scheme: ColorScheme, fontSize: Double) {
        view.nativeBackgroundColor = NSColor(theme.background(scheme))
        view.nativeForegroundColor = NSColor(theme.foreground(scheme))
        let f = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        if view.font.pointSize != f.pointSize { view.font = f }
    }

    func terminate() {
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        view.process.terminate()
    }

    deinit { if let m = clickMonitor { NSEvent.removeMonitor(m) } }

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
