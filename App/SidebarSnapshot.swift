import SwiftUI
import AppKit
import BetterTerminalCore

/// `--render-sidebar <folder>`: used by CI. Renders the real sidebar view with sample workspaces to PNG files
/// (dark and light, expanded and as a rail) and prints them as base64 between markers, so they can be viewed
/// without a screen to capture.
extension AppModel {
    func runSidebarSnapshots(into folder: String) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self else { return }
            try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)

            // Full-height sidebars for the README and website screenshots. They use the colours of the captured
            // window (dark: an imported theme with background #010409; light: the built-in Black theme).
            let darkWindowTheme = Theme(custom: CustomTheme(id: "shot", name: "Shot", background: "#010409",
                                                            foreground: "#E6EDF3", accent: "#58A6FF"))
            struct Variant { let name: String; let scheme: ColorScheme; let collapsed: Bool; let theme: Theme; let height: CGFloat; let window: Bool }
            let variants: [Variant] = [
                Variant(name: "sidebar-dark", scheme: .dark, collapsed: false, theme: Theme.named("default"), height: 740, window: false),
                Variant(name: "sidebar-light", scheme: .light, collapsed: false, theme: Theme.named("default"), height: 740, window: false),
                Variant(name: "sidebar-dark-rail", scheme: .dark, collapsed: true, theme: Theme.named("default"), height: 740, window: false),
                Variant(name: "window-sidebar-dark", scheme: .dark, collapsed: false, theme: darkWindowTheme, height: 1308, window: true),
                Variant(name: "window-sidebar-light", scheme: .light, collapsed: false, theme: Theme.named("mono"), height: 1308, window: true)
            ]
            for v in variants {
                if v.window { self.loadWindowSampleState() } else { self.loadSampleSidebarState() }
                NSApp.appearance = NSAppearance(named: v.scheme == .dark ? .darkAqua : .aqua)
                try? await Task.sleep(for: .milliseconds(300))
                // Sessions started by the window clear the sample's "running" marks: set them again right before drawing.
                if !v.window { self.applySampleActivity() }
                let width = v.collapsed ? SidebarState.collapsedWidth : SidebarState.expandedWidth
                let view = Sidebar(collapsed: .constant(v.collapsed))
                    .environment(self)
                    .environment(\.theme, v.theme)
                    .environment(\.colorScheme, v.scheme)
                    .environment(\.sidebarSnapshot, true)
                    .frame(width: width, height: v.height)
                    .padding(.trailing, v.window ? 14 : 0)      // room for the collapse button that sits on the edge
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    print("BTSNAP-FAILED \(v.name)"); continue
                }
                try? png.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(v.name).png"))
                let b64 = png.base64EncodedString()
                print("BTSNAP-BEGIN \(v.name)")
                var i = b64.startIndex
                while i < b64.endIndex {
                    let j = b64.index(i, offsetBy: 600, limitedBy: b64.endIndex) ?? b64.endIndex
                    print("BTSNAP " + b64[i..<j]); i = j
                }
                print("BTSNAP-END \(v.name)")
            }
            fflush(stdout)
            exit(0)
        }
    }

    /// Generic sample content: nothing from a real machine.
    private func loadSampleSidebarState() {
        func tabs(_ names: [String]) -> [TerminalTab] { names.map { TerminalTab(title: $0, hasCustomTitle: true) } }
        var main = Workspace(name: "Main", colorHex: "#0A84FF", tabs: tabs(["api", "web", "docs", "Terminal 4"]))
        var site = Workspace(name: "Website", colorHex: "#30B26B", tabs: tabs(["Terminal 1", "Terminal 2"]))
        let ops = Workspace(name: "Ops", colorHex: "#FF7A45", tabs: tabs(["servers"]))
        let notes = Workspace(name: "Notes", colorHex: "#8E6CF0", tabs: tabs(["Terminal 1", "Terminal 2"]))
        main.activeTabID = main.tabs[0].id
        site.activeTabID = site.tabs[0].id
        state = AppState(workspaces: [main, site, ops, notes], activeWorkspaceID: main.id)
        route = .terminal
        sampleRunning = [main.tabs[1].id, main.tabs[2].id]
        sampleFailed = [site.tabs[1].id]
        applySampleActivity()
    }

    private func applySampleActivity() {
        runningTabs = sampleRunning
        failedTabs = sampleFailed
    }

    /// The window in the README and website screenshots: Main with six tabs and three more workspaces.
    private func loadWindowSampleState() {
        func tabs(_ names: [String]) -> [TerminalTab] { names.map { TerminalTab(title: $0, hasCustomTitle: true) } }
        var main = Workspace(name: "Main", colorHex: "#0A84FF",
                             tabs: tabs(["better-terminal", "Terminal 3", "Terminal 3", "Terminal 4", "Terminal 5", "Terminal 6"]))
        let w2 = Workspace(name: "Workspace 2", colorHex: "#30B26B", tabs: tabs(["Terminal 1", "Terminal 2"]))
        let w3 = Workspace(name: "Workspace 3", colorHex: "#FF7A45", tabs: tabs(["Terminal 1", "Terminal 2"]))
        let w4 = Workspace(name: "Workspace 4", colorHex: "#8E6CF0", tabs: tabs(["Terminal 2", "Terminal 2"]))
        main.activeTabID = main.tabs[0].id
        state = AppState(workspaces: [main, w2, w3, w4], activeWorkspaceID: main.id)
        route = .terminal
        sampleRunning = []; sampleFailed = []
        applySampleActivity()
    }
}
