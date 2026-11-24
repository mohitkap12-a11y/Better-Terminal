import SwiftUI
import AppKit

/// Drags the window when the mouse is pressed on it. The window is not movable by its background any more
/// (that swallowed every drag on the tab bar), so only this strip moves it. Double-click zooms like a title bar.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { false }
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 { window?.performZoom(nil) } else { window?.performDrag(with: event) }
        }
    }
}

/// Turns off "drag the window from anywhere" so tabs can be dragged to reorder.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { v.window?.isMovableByWindowBackground = false }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { nsView.window?.isMovableByWindowBackground = false }
    }
}

extension View {
    /// Runs `action` on a middle-click (centre button), like closing a tab in a browser.
    func onMiddleClick(_ action: @escaping () -> Void) -> some View {
        overlay(MiddleClickCatcher(action: action))
    }
}

/// Only claims the mouse for middle-button events, so left/right clicks and drags reach the view underneath.
private struct MiddleClickCatcher: NSViewRepresentable {
    let action: () -> Void
    func makeNSView(context: Context) -> CatcherView { CatcherView(action: action) }
    func updateNSView(_ nsView: CatcherView, context: Context) { nsView.action = action }

    final class CatcherView: NSView {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }

        override func hitTest(_ point: NSPoint) -> NSView? {
            switch NSApp.currentEvent?.type {
            case .otherMouseDown, .otherMouseUp, .otherMouseDragged: return super.hitTest(point)
            default: return nil
            }
        }
        override func otherMouseUp(with event: NSEvent) {
            if event.buttonNumber == 2 { action() }
        }
    }
}
