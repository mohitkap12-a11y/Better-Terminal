import AppKit
import Carbon.HIToolbox

/// Keys the quick terminal can be opened with. Pick another if the default clashes with something on your Mac.
enum QuickHotkey: String, CaseIterable, Identifiable {
    case ctrlGrave, optSpace, ctrlOptSpace, f12
    var id: String { rawValue }
    var label: String {
        switch self {
        case .ctrlGrave: return "⌃`  (control + backtick)"
        case .optSpace: return "⌥Space"
        case .ctrlOptSpace: return "⌃⌥Space"
        case .f12: return "F12"
        }
    }
    var keyCode: UInt32 {
        switch self {
        case .ctrlGrave: return UInt32(kVK_ANSI_Grave)
        case .optSpace, .ctrlOptSpace: return UInt32(kVK_Space)
        case .f12: return UInt32(kVK_F12)
        }
    }
    var modifiers: UInt32 {
        switch self {
        case .ctrlGrave: return UInt32(controlKey)
        case .optSpace: return UInt32(optionKey)
        case .ctrlOptSpace: return UInt32(controlKey | optionKey)
        case .f12: return 0
        }
    }
}

/// Drop-down terminal on a global hotkey (⌃`). Not part of any workspace; its shell is kept while the app runs.
@MainActor
final class QuickTerminal {
    static let shared = QuickTerminal()

    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private weak var model: AppModel?
    private var panel: Panel?
    private var session: TerminalSession?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var escMonitor: Any?
    /// The app you were in when you opened it, so hiding gives the keyboard back there.
    private var previousApp: NSRunningApplication?
    /// Where the quick terminal's shell actually is (it reports every folder change), not just where we last sent it.
    private var shellFolder: String?

    /// Lets the quick terminal open on demand (palette, "Show now") even when its hotkey is off.
    func attach(model: AppModel) { self.model = model }

    func start(model: AppModel) {
        attach(model: model)
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                DispatchQueue.main.async { QuickTerminal.shared.toggle() }
                return noErr
            }, 1, &spec, nil, &handler)
        }
        registerHotKey()
    }

    private func registerHotKey() {
        guard hotKey == nil, let model else { return }
        let key = QuickHotkey(rawValue: model.state.quickTerminalHotkey) ?? .ctrlGrave
        let id = EventHotKeyID(signature: OSType(0x42544B59), id: 1)
        let status = RegisterEventHotKey(key.keyCode, key.modifiers, id, GetApplicationEventTarget(), 0, &hotKey)
        if status == noErr {
            model.quickStatus = "Listening for \(key.label)"
            Diagnostics.log("quick terminal hotkey registered: \(key.rawValue)")
        } else {
            hotKey = nil
            model.quickStatus = "Could not register \(key.label) (error \(status)). Try another key."
            Diagnostics.log("quick terminal hotkey registration failed: \(key.rawValue) status \(status)")
        }
    }

    /// Moves the hotkey to the newly chosen key. The panel and its shell are left alone.
    func restart(model: AppModel) {
        attach(model: model)
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        registerHotKey()
    }

    /// Turns the hotkey off and ends the quick terminal's shell.
    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil; handler = nil
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
        panel?.orderOut(nil); panel = nil
        session?.terminate(); session = nil; shellFolder = nil
    }

    func toggle() {
        Diagnostics.log("quick terminal toggled")
        if let panel, panel.isVisible, panel.isKeyWindow { hide() } else { show() }
    }

    private func hide() {
        panel?.orderOut(nil)
        if let app = previousApp, !app.isTerminated { app.activate(options: []) }
        previousApp = nil
    }

    private static let margin: CGFloat = 16
    private static let size = NSSize(width: 580, height: 340)

    // MARK: Which folder to open in

    /// The folder to start in: the front Finder window's folder when you press the key from Finder, or the
    /// current tab's folder when you press it inside Better Terminal. Nil elsewhere (the shell keeps its folder).
    private func launchFolder() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        if app.bundleIdentifier == "com.apple.finder" { return finderFolder() }
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { return model?.activeTabFolder }
        return nil
    }

    private func finderFolder() -> String? {
        let source = """
        tell application "Finder"
            if (count of windows) > 0 then
                return POSIX path of (target of front window as alias)
            else
                return POSIX path of (path to desktop folder)
            end if
        end tell
        """
        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue else {
            Diagnostics.log("quick terminal: could not read the Finder folder (\(error?[NSAppleScript.errorMessage] ?? "unknown")). Allow it in System Settings > Privacy & Security > Automation.")
            return nil
        }
        return result.count > 1 && result.hasSuffix("/") ? String(result.dropLast()) : result
    }

    private func normalized(_ path: String) -> String {
        path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    private func quoted(_ path: String) -> String { "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    // MARK: Show

    private func show() {
        guard let model else { return }
        let folder = launchFolder()          // ask before this app takes focus
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = front }
        if session == nil {
            session = model.makeEphemeralSession(name: "Quick Terminal", cwd: folder, onCwd: { [weak self] in
                self?.shellFolder = self?.normalized($0)
            }, onExit: { [weak self] in
                // Shell exited: close the panel; the next toggle starts a fresh shell.
                self?.hide(); self?.panel = nil; self?.session = nil; self?.shellFolder = nil
            })
            shellFolder = folder.map(normalized)
        } else if let folder, normalized(folder) != shellFolder, session?.hasRunningCommand == false {
            // The shell is somewhere else (you cd'd away, or came from another folder): follow the requested one.
            session?.run("cd " + quoted(folder))
        }
        guard let session else { return }
        session.apply(theme: model.theme, scheme: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light,
                      fontSize: model.state.terminalFontSize, fontFamily: model.state.terminalFontFamily)
        if panel == nil {
            let p = Panel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.isMovable = false
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            // Rounded card around the terminal.
            let box = NSView()
            box.wantsLayer = true
            box.layer?.cornerRadius = 12
            box.layer?.masksToBounds = true
            box.layer?.borderWidth = 1
            box.layer?.borderColor = NSColor.separatorColor.cgColor
            let v = session.nsView
            v.removeFromSuperview()
            v.frame = box.bounds
            v.autoresizingMask = [.width, .height]
            box.addSubview(v)
            p.contentView = box
            panel = p
        }
        installEscapeMonitor()
        // Bottom-right corner of the screen the pointer is on.
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let area = screen.visibleFrame
        let w = min(Self.size.width, area.width - 2 * Self.margin), h = min(Self.size.height, area.height - 2 * Self.margin)
        let target = NSRect(x: area.maxX - w - Self.margin, y: area.minY + Self.margin, width: w, height: h)
        guard let panel else { return }
        panel.setFrame(target.offsetBy(dx: 0, dy: -(h + 2 * Self.margin)), display: false)   // start below the screen edge
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel.animator().setFrame(target, display: true)
        }
        session.focus()
    }

    /// Esc hides the quick terminal, unless a command is running (then Esc goes to the program, e.g. vim).
    private func installEscapeMonitor() {
        guard escMonitor == nil else { return }
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, let self, let panel = self.panel, event.window === panel,
                  self.session?.hasRunningCommand != true else { return event }
            self.hide()
            return nil
        }
    }
}
