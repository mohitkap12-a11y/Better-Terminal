import SwiftUI
import BetterTerminalCore

struct TabBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let workspace: Workspace

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
            if workspace.broadcast {
                Button { model.toggleBroadcast() } label: {
                    Label("Broadcast", systemImage: "dot.radiowaves.left.and.right").font(.caption)
                }
                .buttonStyle(.bordered).controlSize(.small).tint(.orange)
                .help("Typing goes to every pane. Click to stop (⌥⌘I)")
            }
            Button { model.layoutPickerOpen.toggle() } label: {
                HStack(spacing: Metrics.s1) {
                    Image(systemName: "square.grid.2x2")
                    Text(workspace.layout.label).monospacedDigit()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Pane layout, \(workspace.layout.label)")
            .help("Pane layout (⌥⌘L)")
            .popover(isPresented: Bindable(model).layoutPickerOpen, arrowEdge: .bottom) { LayoutPicker(isPresented: Bindable(model).layoutPickerOpen) }
        }
        .padding(.horizontal, Metrics.s3)
        .padding(.top, Metrics.s2)
        .frame(height: 40)
        .background(theme.groundColor)
        .background(WindowDragArea())
    }
}

private struct TabChip: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let tab: TerminalTab
    let selected: Bool
    let canClose: Bool
    @State private var hovering = false
    @State private var dropTarget = false

    var body: some View {
        HStack(spacing: Metrics.s1) {
            Image(systemName: "terminal").font(.caption).foregroundStyle(.secondary)
            Text(tab.title).lineLimit(1).font(.callout)
            TabStatusBadge(id: tab.id, selected: selected)
            if canClose {
                Button { model.requestCloseTab(tab.id) } label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .opacity(hovering || selected ? 1 : 0)
                .accessibilityLabel("Close \(tab.title)")
            }
        }
        .padding(.horizontal, Metrics.s2)
        .frame(height: 28)
        .background(selected ? theme.selection : Color.clear,
                    in: RoundedRectangle(cornerRadius: Metrics.radiusControl))
        .contentShape(Rectangle())
        .overlay(alignment: .leading) {
            if dropTarget { Capsule().fill(theme.accent).frame(width: 3, height: 20).offset(x: -3) }   // drop here
        }
        // Single tap acts at once; waiting to rule out a double-tap made switching feel slow.
        .onTapGesture { model.mutateActive { $0.activeTabID = tab.id } }
        .simultaneousGesture(TapGesture(count: 2).onEnded { model.beginRenameTab(tab) })
        .onMiddleClick { model.requestCloseTab(tab.id) }
        .onChange(of: selected) { if selected { model.failedTabs.remove(tab.id) } }
        .onHover { hovering = $0 }
        // Tabs are reordered and moved from the sidebar. Dragging a chip here used to move the whole window as well,
        // so the chips are not draggable (they still accept a tab dropped from the sidebar).
        .dropDestination(for: String.self) { items, _ in
            model.handleDrop(items, ontoTab: tab.id)
        } isTargeted: { dropTarget = $0 }
        .tabContextMenu(tab)
    }
}
