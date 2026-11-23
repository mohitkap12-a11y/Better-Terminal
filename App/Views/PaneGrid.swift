import SwiftUI
import BetterTerminalCore

/// Shows every tab of the workspace as a pane, arranged by the workspace layout.
struct PaneGrid: View {
    @Environment(AppModel.self) private var model
    let workspace: Workspace

    var body: some View {
        let layout = workspace.layout
        let rows = layout.rowsNeeded(forPaneCount: workspace.tabs.count)
        Grid(horizontalSpacing: 1, verticalSpacing: 1) {
            ForEach(0..<rows, id: \.self) { r in
                GridRow {
                    ForEach(0..<layout.columns, id: \.self) { c in
                        let i = r * layout.columns + c
                        if i < workspace.tabs.count {
                            PaneView(tab: workspace.tabs[i],
                                     focused: workspace.tabs[i].id == workspace.activeTabID)
                                .id("\(workspace.tabs[i].id)-\(model.restartCounter)")
                        } else {
                            EmptyPane()
                        }
                    }
                }
            }
        }
        .background(.separator)
        .animation(.easeOut(duration: 0.15), value: workspace.layout)
    }
}

private struct EmptyPane: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(spacing: Metrics.s2) {
            Image(systemName: "plus.rectangle.on.rectangle").font(.title2).foregroundStyle(.tertiary)
            Text("Empty pane").foregroundStyle(.secondary)
            Button("New Tab") { model.newTab() }.controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
