import SwiftUI
import BetterTerminalCore

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            WorkspaceRail()
            Divider()
            if let ws = model.active {
                WorkspaceView(workspace: ws)
                    .id(ws.id)
            } else {
                ContentUnavailableView("No workspace", systemImage: "rectangle.stack",
                                       description: Text("Create a workspace to get started."))
            }
        }
        .background(.background)
        .ignoresSafeArea(.container, edges: .top)
    }
}

struct WorkspaceView: View {
    @Environment(AppModel.self) private var model
    let workspace: Workspace

    var body: some View {
        VStack(spacing: 0) {
            TabBar(workspace: workspace)
            Divider()
            PaneGrid(workspace: workspace)
        }
    }
}
