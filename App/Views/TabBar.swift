import SwiftUI
import BetterTerminalCore

struct TabBar: View {
    @Environment(AppModel.self) private var model
    let workspace: Workspace
    @State private var showLayout = false

    var body: some View {
        HStack(spacing: Metrics.s1) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metrics.s1) {
                    ForEach(workspace.tabs) { tab in
                        TabChip(tab: tab, selected: tab.id == workspace.activeTabID,
                                canClose: workspace.tabs.count > 1)
                    }
                }
            }
            Button { model.newTab() } label: { Image(systemName: "plus") }
                .buttonStyle(.borderless)
                .accessibilityLabel("New tab")
                .help("New tab (⌘T)")
            Spacer(minLength: Metrics.s2)
            Button { showLayout.toggle() } label: {
                HStack(spacing: Metrics.s1) {
                    Image(systemName: "square.grid.2x2")
                    Text(workspace.layout.label).monospacedDigit()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Pane layout, \(workspace.layout.label)")
            .help("Pane layout")
            .popover(isPresented: $showLayout, arrowEdge: .bottom) { LayoutPicker(isPresented: $showLayout) }
        }
        .padding(.horizontal, Metrics.s3)
        .padding(.top, Metrics.s2)
        .frame(height: 40)
        .background(.bar)
    }
}

private struct TabChip: View {
    @Environment(AppModel.self) private var model
    let tab: TerminalTab
    let selected: Bool
    let canClose: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: Metrics.s1) {
            Image(systemName: "terminal").font(.caption).foregroundStyle(.secondary)
            Text(tab.title).lineLimit(1).font(.callout)
            if canClose {
                Button { model.closeTab(tab.id) } label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .opacity(hovering || selected ? 1 : 0)
                .accessibilityLabel("Close \(tab.title)")
            }
        }
        .padding(.horizontal, Metrics.s2)
        .frame(height: 28)
        .background(selected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: Metrics.radiusControl))
        .contentShape(Rectangle())
        .onTapGesture { model.mutateActive { $0.activeTabID = tab.id } }
        .onHover { hovering = $0 }
    }
}
