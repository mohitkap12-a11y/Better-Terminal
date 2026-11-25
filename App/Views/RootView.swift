import SwiftUI
import BetterTerminalCore

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @AppStorage(SidebarState.storageKey) private var sidebarCollapsed = true
    @AppStorage("walkthroughSeen") private var walkthroughSeen = false

    var body: some View {
        ZStack(alignment: .topLeading) {
          HStack(spacing: 0) {
            // Space for the sidebar (the rail's width when collapsed). The sidebar itself is drawn on top, so
            // peeking at the rail covers the terminals instead of pushing and re-flowing them.
            Color.clear.frame(width: sidebarCollapsed ? SidebarState.collapsedWidth : SidebarState.expandedWidth)
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
          Sidebar(collapsed: $sidebarCollapsed).zIndex(1)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(WindowConfigurator())
        .overlay { popups }
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
        .animation(.easeOut(duration: 0.14), value: model.paletteOpen || model.shortcutsOpen)
        .onAppear {
            model.applyAppearance()
            if !walkthroughSeen { model.walkthroughOpen = true }
        }
        .onChange(of: model.focusKey) { model.scheduleFocusSync() }
        .onChange(of: model.sidebarToggleTick) { withAnimation(SidebarState.animation) { sidebarCollapsed.toggle() } }
        .onChange(of: model.state.themeMode) { model.applyAppearance() }
        .onChange(of: model.state.themeID) { model.applyAppearance() }
        .onChange(of: model.state.customThemes) { model.applyAppearance() }
    }
}

extension RootView {
    /// The search palette and the shortcuts popup: a card over a dimmed backdrop. A click anywhere outside the card
    /// (the terminals, the sidebar, the tab bar) closes it, and so does esc.
    @ViewBuilder fileprivate var popups: some View {
        if model.paletteOpen || model.shortcutsOpen {
            ZStack {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { model.paletteOpen = false; model.shortcutsOpen = false }
                    .accessibilityLabel("Close")
                    .accessibilityAddTraits(.isButton)
                Group {
                    if model.paletteOpen { CommandPalette() } else { ShortcutsPopup() }
                }
                .background(theme.groundColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(theme.border))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 28, y: 10)
                .onExitCommand { model.paletteOpen = false; model.shortcutsOpen = false }
            }
            .transition(.opacity)
        }
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
