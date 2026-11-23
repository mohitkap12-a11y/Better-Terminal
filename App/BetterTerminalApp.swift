import SwiftUI
import BetterTerminalCore

@main
struct BetterTerminalApp: App {
    @State private var model = AppModel()

    init() { AppIcon.install() }
    @StateObject private var updater = UpdaterService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environmentObject(updater)
                .environment(\.theme, model.theme)
                .preferredColorScheme(model.colorScheme)
                .tint(model.theme.accent)
                .frame(minWidth: 860, minHeight: 520)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    model.saveNow()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.isAvailable || !updater.canCheckForUpdates)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { model.route = .settings }.keyboardShortcut(",")
            }
            CommandGroup(replacing: .newItem) {
                Button("New Tab") { model.route = .terminal; model.newTab() }.keyboardShortcut("t")
                Button("New Workspace") { model.addWorkspace() }.keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Close Tab") {
                    if let id = model.active?.activeTabID { model.closeTab(id) }
                }.keyboardShortcut("w").disabled((model.active?.tabs.count ?? 0) < 2)
            }
            CommandMenu("View") {
                Button("Command Palette") { model.paletteOpen = true }.keyboardShortcut("k")
                Button("Pane Layout") { model.layoutPickerOpen.toggle() }.keyboardShortcut("l", modifiers: [.command, .option])
                Button("Command History") { model.toggleHistory() }.keyboardShortcut("h", modifiers: [.command, .shift])
                Button("Bigger Text") { model.state.terminalFontSize = min(32, model.state.terminalFontSize + 1) }
                    .keyboardShortcut("+")
                Button("Smaller Text") { model.state.terminalFontSize = max(9, model.state.terminalFontSize - 1) }
                    .keyboardShortcut("-")
            }
            CommandMenu("Workspace") {
                ForEach(0..<9, id: \.self) { i in
                    Button("Workspace \(i + 1)") { model.selectWorkspace(at: i) }
                        .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [.control, .command])
                }
            }
        }
    }
}
