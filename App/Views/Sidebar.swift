import SwiftUI
import BetterTerminalCore

enum SidebarState {
    static let storageKey = "sidebarCollapsed"
    static let expandedWidth: CGFloat = 236
    static let collapsedWidth: CGFloat = 80
    static let animation = Animation.spring(response: 0.38, dampingFraction: 0.86)
}

/// Full-width sidebar (or an icon rail) with the workspaces, search and settings.
/// Leaves room at the top for the window's traffic-light buttons.
struct Sidebar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Binding var collapsed: Bool

    @State private var renaming: Workspace?
    @State private var newName = ""
    @State private var deleting: Workspace?
    @State private var targetedWorkspace: UUID?
    @State private var targetedNew = false
    /// The whole WORKSPACES list folded away, and the ids of workspaces whose tabs are folded (comma-separated).
    @AppStorage("sidebarWorkspacesFolded") private var sectionFolded = false
    @AppStorage("sidebarFoldedWorkspaces") private var foldedText = ""

    private var foldedWorkspaces: Set<String> { Set(foldedText.split(separator: ",").map(String.init)) }

    private func toggleFolded(_ id: UUID) {
        var ids = foldedText.split(separator: ",").map(String.init).filter { !$0.isEmpty }
        if ids.contains(id.uuidString) { ids.removeAll { $0 == id.uuidString } } else { ids.append(id.uuidString) }
        withAnimation(.easeOut(duration: 0.15)) { foldedText = ids.joined(separator: ",") }
    }

    private let colors = ["#0A84FF", "#30B26B", "#FF7A45", "#8E6CF0", "#FF375F", "#64D2FF"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Brand(collapsed: collapsed)
                .padding(.horizontal, collapsed ? 0 : 16)
                .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
                .padding(.top, 52)           // clears the traffic lights
                .padding(.bottom, 18)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 3) {
                    if collapsed {
                        workspaceRows
                    } else {
                        // The whole list can be folded away, and each workspace folds its own tabs (remembered).
                        SectionHeader(title: "WORKSPACES", folded: sectionFolded, count: model.state.workspaces.count) {
                            withAnimation(.easeOut(duration: 0.15)) { sectionFolded.toggle() }
                        }
                        if !sectionFolded { workspaceRows }
                    }
                }
                .padding(.horizontal, 10)
            }

            Spacer(minLength: 0)
            Rectangle().fill(theme.hairline).frame(height: 1).padding(.horizontal, 14)
            VStack(alignment: .leading, spacing: 3) {
                SidebarRow(title: "Search", isSelected: false, collapsed: collapsed,
                           action: { model.paletteOpen = true }) {
                    icon("magnifyingglass", selected: false)
                } trailing: { shortcut("⌘K") }
                SidebarRow(title: "Settings", isSelected: model.route == .settings, collapsed: collapsed,
                           action: { model.route = .settings }) {
                    icon("gearshape", selected: model.route == .settings)
                } trailing: { shortcut("⌘,") }
            }
            .padding(10)
        }
        .frame(width: collapsed ? SidebarState.collapsedWidth : SidebarState.expandedWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.sidebar)
        // Title-bar strip that drags the window (the traffic lights sit on top of it).
        .overlay(alignment: .top) { WindowDragArea().frame(height: 40) }
        .clipped()
        .overlay(alignment: .trailing) { Rectangle().fill(theme.border).frame(width: 1) }
        .overlay(alignment: .topTrailing) {
            SidebarToggle(collapsed: $collapsed).offset(x: 11, y: 56)
        }
        .alert("Rename workspace", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") { if let r = renaming { model.rename(r.id, to: newName) }; renaming = nil }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .confirmationDialog("Delete “\(deleting?.name ?? "")”?",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("Delete workspace and history", role: .destructive) {
                if let d = deleting { model.deleteWorkspace(d.id) }
                deleting = nil
            }
        }
    }

    /// Every workspace, with its tabs underneath unless folded, then the New Workspace row.
    @ViewBuilder private var workspaceRows: some View {
        ForEach(Array(model.state.workspaces.enumerated()), id: \.element.id) { index, ws in
            let selected = model.route == .terminal && ws.id == model.state.activeWorkspaceID
            let folded = foldedWorkspaces.contains(ws.id.uuidString)
            HStack(spacing: 0) {
                SidebarRow(title: ws.name, isSelected: selected, collapsed: collapsed,
                           action: { model.state.activeWorkspaceID = ws.id; model.route = .terminal }) {
                    WorkspaceBadge(ws: ws, selected: selected)
                } trailing: {
                    shortcut("⌃⌘\(index + 1)")
                }
                .overlay {
                    if targetedWorkspace == ws.id {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(theme.accent, lineWidth: 1.5)
                    }
                }
                .draggable(AppModel.workspacePayload(ws.id))
                .dropDestination(for: String.self) { items, _ in
                    model.handleDrop(items, ontoWorkspace: ws.id)
                } isTargeted: { targetedWorkspace = $0 ? ws.id : (targetedWorkspace == ws.id ? nil : targetedWorkspace) }
                .contextMenu {
                    Button("New Terminal") { model.newTab(in: ws.id) }
                    Button("Save as Template") { model.saveTemplate(from: ws.id) }
                    Divider()
                    Button("Rename…") { newName = ws.name; renaming = ws }
                    Menu("Color") {
                        ForEach(colors, id: \.self) { hex in
                            Button { model.setColor(ws.id, hex: hex) } label: { Label(hex, systemImage: "circle.fill") }
                        }
                    }
                    Divider()
                    Button(folded ? "Show Tabs" : "Hide Tabs") { toggleFolded(ws.id) }
                    Button("Delete…", role: .destructive) { deleting = ws }
                        .disabled(model.state.workspaces.count < 2)
                }
                if !collapsed {
                    FoldButton(folded: folded, label: ws.name) { toggleFolded(ws.id) }
                }
            }
            // Tabs: click to switch, drag to reorder or onto another workspace.
            if !collapsed && !folded {
                ForEach(ws.tabs) { tab in
                    SidebarTabRow(tab: tab, selected: model.route == .terminal && ws.id == model.state.activeWorkspaceID && tab.id == ws.activeTabID)
                }
            }
        }
        SidebarRow(title: "New Workspace", isSelected: false, collapsed: collapsed,
                   action: { model.addWorkspace() }) {
            icon("plus", selected: false)
        } trailing: { shortcut("⇧⌘N") }
        .overlay {
            if targetedNew {
                RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(theme.accent, lineWidth: 1.5)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            model.handleDropOnNewWorkspace(items)
        } isTargeted: { targetedNew = $0 }
    }

    private func icon(_ name: String, selected: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(selected ? theme.accent : theme.muted)
    }

    private func shortcut(_ keys: String) -> some View {
        Text(keys).font(.system(size: 11)).foregroundStyle(theme.faint)
    }
}

private struct WorkspaceBadge: View {
    let ws: Workspace
    let selected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: ws.colorHex).opacity(selected ? 1 : 0.2))
            Text(String(ws.name.prefix(1)).uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Color.white : Color(hex: ws.colorHex))
        }
        .frame(width: 22, height: 22)
    }
}

private struct Brand: View {
    let collapsed: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon).resizable().interpolation(.high).frame(width: 40, height: 40).padding(-4)
            }
            if !collapsed {
                Text("Better Terminal").font(.system(size: 14, weight: .semibold)).fixedSize().transition(.opacity)
            }
        }
    }
}

/// The round button on the sidebar's edge that collapses it to icons and back.
private struct SidebarToggle: View {
    @Environment(\.theme) private var theme
    @Binding var collapsed: Bool
    @State private var hovering = false

    var body: some View {
        Button { withAnimation(SidebarState.animation) { collapsed.toggle() } } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 9, weight: .bold))
                .rotationEffect(.degrees(collapsed ? 180 : 0))
                .foregroundStyle(hovering ? Color.primary : theme.muted)
                .frame(width: 22, height: 22)
                .background(theme.groundColor, in: Circle())
                .overlay(Circle().strokeBorder(theme.border))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(collapsed ? "Expand sidebar (⌃⌘S)" : "Collapse sidebar (⌃⌘S)")
        .accessibilityLabel(collapsed ? "Expand sidebar" : "Collapse sidebar")
    }
}

/// One sidebar entry: icon, title and trailing hint; as a rail, the icon alone with the title as a tooltip.
struct SidebarRow<Icon: View, Trailing: View>: View {
    @Environment(\.theme) private var theme
    let title: String
    var isSelected = false
    let collapsed: Bool
    let action: () -> Void
    @ViewBuilder var icon: () -> Icon
    @ViewBuilder var trailing: () -> Trailing
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                icon().frame(width: 22, height: 22)
                if !collapsed {
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected || hovering ? Color.primary : theme.muted)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    trailing()
                }
            }
            .padding(.leading, collapsed ? 0 : 10)
            .padding(.trailing, collapsed ? 0 : 10)
            .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
            .frame(height: 32)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.selection)
                } else if hovering {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.hover)
                }
            }
            .overlay(alignment: .leading) {
                if isSelected { Capsule().fill(theme.accent).frame(width: 3, height: 16).offset(x: -4) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .help(collapsed ? title : "")
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A tab listed under its workspace in the sidebar.
private struct SidebarTabRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let tab: TerminalTab
    let selected: Bool
    @State private var hovering = false
    @State private var dropTarget = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal").font(.system(size: 10.5)).foregroundStyle(selected ? theme.accent : theme.faint)
            Text(tab.title).font(.system(size: 12, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? Color.primary : theme.muted).lineLimit(1)
            Spacer(minLength: 0)
            TabStatusBadge(id: tab.id, selected: selected)
        }
        .padding(.leading, 40).padding(.trailing, 10)
        .frame(height: 26)
        .background(selected ? theme.hover : (hovering ? theme.hover.opacity(0.5) : Color.clear),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(alignment: .top) {
            if dropTarget { Capsule().fill(theme.accent).frame(height: 2).padding(.leading, 36).offset(y: -1) }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { model.select(tab: tab.id) }
        .simultaneousGesture(TapGesture(count: 2).onEnded { model.beginRenameTab(tab) })
        .onMiddleClick { model.requestCloseTab(tab.id) }
        .draggable(AppModel.tabPayload(tab.id))
        .dropDestination(for: String.self) { items, _ in
            model.handleDrop(items, ontoTab: tab.id)
        } isTargeted: { dropTarget = $0 }
        .tabContextMenu(tab)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// "WORKSPACES" heading that folds the whole list.
private struct SectionHeader: View {
    @Environment(\.theme) private var theme
    let title: String
    let folded: Bool
    let count: Int
    let toggle: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8.5, weight: .bold))
                    .rotationEffect(.degrees(folded ? 0 : 90))
                Text(title).font(.system(size: 10.5, weight: .semibold)).tracking(0.6)
                if folded {
                    Text("\(count)").font(.system(size: 10, weight: .semibold)).monospacedDigit()
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(theme.track, in: Capsule())
                }
                Spacer()
            }
            .foregroundStyle(hovering ? theme.muted : theme.faint)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .padding(.bottom, 2)
        .accessibilityLabel("\(title.capitalized), \(folded ? "collapsed" : "expanded")")
        .help(folded ? "Show workspaces" : "Hide workspaces")
    }
}

/// Small chevron at the end of a workspace row that folds or unfolds its tabs.
private struct FoldButton: View {
    @Environment(\.theme) private var theme
    let folded: Bool
    let label: String
    let toggle: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: toggle) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .rotationEffect(.degrees(folded ? 0 : 90))
                .foregroundStyle(hovering ? Color.primary : theme.faint)
                .frame(width: 22, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("\(folded ? "Show" : "Hide") tabs of \(label)")
        .help(folded ? "Show tabs" : "Hide tabs")
    }
}
