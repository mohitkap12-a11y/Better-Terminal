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
                    if !collapsed {
                        Text("WORKSPACES").font(.system(size: 10.5, weight: .semibold)).tracking(0.6)
                            .foregroundStyle(theme.faint)
                            .padding(.horizontal, 12).padding(.bottom, 4)
                    }
                    ForEach(Array(model.state.workspaces.enumerated()), id: \.element.id) { index, ws in
                        let selected = model.route == .terminal && ws.id == model.state.activeWorkspaceID
                        SidebarRow(title: ws.name, isSelected: selected, collapsed: collapsed,
                                   action: { model.state.activeWorkspaceID = ws.id; model.route = .terminal }) {
                            WorkspaceBadge(ws: ws, selected: selected)
                        } trailing: {
                            shortcut("⌃⌘\(index + 1)")
                        }
                        .contextMenu {
                            Button("Rename…") { newName = ws.name; renaming = ws }
                            Menu("Color") {
                                ForEach(colors, id: \.self) { hex in
                                    Button { model.setColor(ws.id, hex: hex) } label: { Label(hex, systemImage: "circle.fill") }
                                }
                            }
                            Divider()
                            Button("Delete…", role: .destructive) { deleting = ws }
                                .disabled(model.state.workspaces.count < 2)
                        }
                    }
                    SidebarRow(title: "New Workspace", isSelected: false, collapsed: collapsed,
                               action: { model.addWorkspace() }) {
                        icon("plus", selected: false)
                    } trailing: { shortcut("⇧⌘N") }
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
