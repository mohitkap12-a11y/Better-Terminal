import SwiftUI
import BetterTerminalCore

@main
struct BetterTerminalApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(\.theme, model.theme)
                .preferredColorScheme(model.colorScheme)
                .tint(model.theme.accent)
                .frame(minWidth: 760, minHeight: 480)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    model.saveNow()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") { model.newTab() }.keyboardShortcut("t")
                Button("New Workspace") { model.addWorkspace() }.keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Close Tab") {
                    if let id = model.active?.activeTabID { model.closeTab(id) }
                }.keyboardShortcut("w")
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

        Settings {
            SettingsView()
                .environment(model)
                .environment(\.theme, model.theme)
                .preferredColorScheme(model.colorScheme)
                .tint(model.theme.accent)
        }
    }
}
