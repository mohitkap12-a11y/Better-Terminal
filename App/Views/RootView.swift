import SwiftUI
import BetterTerminalCore

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @AppStorage(SidebarState.storageKey) private var sidebarCollapsed = true
    @AppStorage("walkthroughSeen") private var walkthroughSeen = false

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(collapsed: $sidebarCollapsed).zIndex(1)
            Group {
                switch model.route {
                case .terminal:
                    if let ws = model.active {
                        WorkspaceView(workspace: ws).id(ws.id)
                    } else {
                        ContentUnavailableView("No workspace", systemImage: "rectangle.stack",
                                               description: Text("Create a workspace to get started."))
                    }
                case .settings:
                    SettingsPage().overlay(alignment: .top) { WindowDragArea().frame(height: 28) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.groundColor)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(WindowConfigurator())
        .sheet(isPresented: Bindable(model).paletteOpen) { CommandPalette() }
        .sheet(isPresented: Bindable(model).shortcutsOpen) { ShortcutsPopup() }
        .alert("Rename tab", isPresented: Binding(get: { model.renamingTab != nil },
                                                  set: { if !$0 { model.renamingTab = nil } })) {
            TextField("Name", text: Bindable(model).renameText)
            Button("Rename") { model.commitRenameTab() }
            Button("Cancel", role: .cancel) { model.renamingTab = nil }
        } message: {
            Text("Leave it empty to use the title your shell sets.")
        }
        .overlay {
            if model.walkthroughOpen {
                Walkthrough { walkthroughSeen = true; model.walkthroughOpen = false }
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.walkthroughOpen)
        .onAppear {
            model.applyAppearance()
            if !walkthroughSeen { model.walkthroughOpen = true }
        }
        .onChange(of: model.state.themeMode) { model.applyAppearance() }
        .onChange(of: model.state.themeID) { model.applyAppearance() }
        .onChange(of: model.state.customThemes) { model.applyAppearance() }
    }
}

struct WorkspaceView: View {
    @Environment(AppModel.self) private var model
    let workspace: Workspace

    var body: some View {
        VStack(spacing: 0) {
            NoWindowDrag { TabBar(workspace: workspace) }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            Divider()
            PaneGrid(workspace: workspace)
        }
    }
}
