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
        panel?.orderOut(nil); panel = nil
        session?.terminate(); session = nil
    }

    func toggle() {
        Diagnostics.log("quick terminal toggled")
        if let panel, panel.isVisible, panel.isKeyWindow { hide() } else { show() }
    }

    private func hide() { panel?.orderOut(nil) }

    private func show() {
        guard let model else { return }
        if session == nil {
            session = model.makeEphemeralSession(name: "Quick Terminal") { [weak self] in
                // Shell exited: close the panel; the next toggle starts a fresh shell.
                self?.panel?.orderOut(nil); self?.panel = nil; self?.session = nil
            }
        }
        guard let session else { return }
        session.apply(theme: model.theme, scheme: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light,
                      fontSize: model.state.terminalFontSize, fontFamily: model.state.terminalFontFamily)
        if panel == nil {
            let p = Panel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.isMovable = false
            p.hasShadow = true
            p.contentView = session.nsView
            panel = p
        }
        guard let panel, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let area = screen.visibleFrame
        let height = (area.height * 0.42).rounded()
        let target = NSRect(x: area.minX, y: area.maxY - height, width: area.width, height: height)
        panel.setFrame(target.offsetBy(dx: 0, dy: height), display: false)       // start above the screen edge
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel.animator().setFrame(target, display: true)
        }
        session.focus()
    }
}
