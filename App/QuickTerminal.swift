import AppKit
import Carbon.HIToolbox

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

    func start(model: AppModel) {
        self.model = model
        guard hotKey == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { QuickTerminal.shared.toggle() }
            return noErr
        }, 1, &spec, nil, &handler)
        let id = EventHotKeyID(signature: OSType(0x42544B59), id: 1)
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_Grave), UInt32(controlKey), id, GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr { Diagnostics.log("quick terminal hotkey registration failed: \(status)") }
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil; handler = nil
        panel?.orderOut(nil); panel = nil
        session?.terminate(); session = nil
    }

    private func toggle() {
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
