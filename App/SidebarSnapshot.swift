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
            self.loadSampleSidebarState()
            try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            let variants: [(String, ColorScheme, Bool)] = [
                ("sidebar-dark", .dark, false), ("sidebar-light", .light, false), ("sidebar-dark-rail", .dark, true)
            ]
            for (name, scheme, collapsed) in variants {
                NSApp.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                try? await Task.sleep(for: .milliseconds(300))
                let view = Sidebar(collapsed: .constant(collapsed))
                    .environment(self)
                    .environment(\.theme, Theme.named("default"))
                    .environment(\.colorScheme, scheme)
                    .environment(\.sidebarSnapshot, true)
                    .frame(width: collapsed ? SidebarState.collapsedWidth : SidebarState.expandedWidth, height: 740)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    print("BTSNAP-FAILED \(name)"); continue
                }
                try? png.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).png"))
                let b64 = png.base64EncodedString()
                print("BTSNAP-BEGIN \(name)")
                var i = b64.startIndex
                while i < b64.endIndex {
                    let j = b64.index(i, offsetBy: 600, limitedBy: b64.endIndex) ?? b64.endIndex
                    print("BTSNAP " + b64[i..<j]); i = j
                }
                print("BTSNAP-END \(name)")
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
        runningTabs = [main.tabs[1].id, main.tabs[2].id]
        failedTabs = [site.tabs[1].id]
    }
}
