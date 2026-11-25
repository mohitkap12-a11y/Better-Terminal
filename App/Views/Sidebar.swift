import SwiftUI
import BetterTerminalCore

enum SidebarState {
    static let storageKey = "sidebarCollapsed"
    static let expandedWidth: CGFloat = 252
    static let collapsedWidth: CGFloat = 72
    /// One easing for the whole sidebar: quick start, soft landing (the width, the chevron, the labels).
    static let animation = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.26)
    static let labelFade = Animation.easeOut(duration: 0.16)
    static let selection = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.28)
}

private struct SidebarSnapshotKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// True while the sidebar is rendered to an image in CI: no scroll view and no window-drag strip, which cannot be drawn offscreen.
    var sidebarSnapshot: Bool {
        get { self[SidebarSnapshotKey.self] }
        set { self[SidebarSnapshotKey.self] = newValue }
    }
}

extension View {
    /// Applies `transform` only when `condition` holds (used to leave out drag and drop while rendering a snapshot).
    @ViewBuilder func applying<V: View>(if condition: Bool, _ transform: (Self) -> V) -> some View {
        if condition { transform(self) } else { self }
    }
}

/// Full-width sidebar (or an icon rail) with the workspaces, search and settings.
/// Leaves room at the top for the window's traffic-light buttons.
struct Sidebar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.sidebarSnapshot) private var snapshot
    @Binding var collapsed: Bool
    /// The rail temporarily opens while the pointer is over it (so you can switch tabs), and closes when it leaves.
    @State private var peeking = false
    @State private var peekTask: Task<Void, Never>?
    /// What is drawn: the rail, unless the sidebar is expanded or being peeked at.
    private var rail: Bool { collapsed && !peeking }

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
            Brand(collapsed: rail)
                .padding(.horizontal, rail ? 0 : 16)
                .frame(maxWidth: .infinity, alignment: rail ? .center : .leading)
                .padding(.top, 52)           // clears the traffic lights
                .padding(.bottom, 18)

            if snapshot {
                workspaceList
            } else {
                ScrollView(showsIndicators: false) { workspaceList }
            }

            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 3) {
                SidebarRow(title: "Search", isSelected: false, collapsed: rail,
                           action: { model.paletteOpen = true }) {
                    icon("magnifyingglass", selected: false)
                } trailing: { shortcut("⌘K") }
                SidebarRow(title: "Shortcuts", isSelected: false, collapsed: rail,
                           action: { model.shortcutsOpen = true }) {
                    icon("keyboard", selected: false)
                } trailing: { shortcut("⌘/") }
                SidebarRow(title: "Settings", isSelected: model.route == .settings, collapsed: rail,
                           action: { model.route = .settings }) {
                    icon("gearshape", selected: model.route == .settings)
                } trailing: { shortcut("⌘,") }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 4)
            Rectangle().fill(theme.hairline).frame(height: 1)
            SidebarFooter(collapsed: rail)
        }
        .frame(width: rail ? SidebarState.collapsedWidth : SidebarState.expandedWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.sidebar)
        // Title-bar strip that drags the window (the traffic lights sit on top of it).
        .overlay(alignment: .top) { if !snapshot { WindowDragArea().frame(height: 40) } }
        .clipped()
        .overlay(alignment: .trailing) { Rectangle().fill(theme.border).frame(width: 1) }
        .shadow(color: .black.opacity(peeking ? 0.28 : 0), radius: 18, x: 6)         // floats above the terminals while peeking
        .onHover { inside in setPeek(inside) }
        .onChange(of: collapsed) { if !collapsed { peekTask?.cancel(); peeking = false } }
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

    /// Opens the rail shortly after the pointer enters it and closes it a moment after it leaves (so passing by or a
    /// small slip out of the edge does not make it flicker).
    private func setPeek(_ inside: Bool) {
        peekTask?.cancel()
        guard collapsed else { peeking = false; return }
        peekTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(inside ? 140 : 240))
            if Task.isCancelled { return }
            withAnimation(SidebarState.animation) { peeking = inside }
        }
    }

    /// The WORKSPACES section (or the plain list in the rail).
    private var workspaceList: some View {
        VStack(alignment: .leading, spacing: 3) {
                    if rail {
                        // The rail has no headings: a thin divider stands in for "WORKSPACES".
                        Rectangle().fill(theme.hairline).frame(height: 1).padding(.horizontal, 14).padding(.vertical, 6)
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

    /// Every workspace, with its tabs underneath unless folded, then the New Workspace row.
    @ViewBuilder private var workspaceRows: some View {
        ForEach(Array(model.state.workspaces.enumerated()), id: \.element.id) { index, ws in
            let selected = model.route == .terminal && ws.id == model.state.activeWorkspaceID
            let folded = foldedWorkspaces.contains(ws.id.uuidString)
            HStack(spacing: 0) {
                SidebarRow(title: ws.name, isSelected: selected, collapsed: rail,
                           action: { model.state.activeWorkspaceID = ws.id; model.route = .terminal }) {
                    WorkspaceBadge(ws: ws, selected: selected, activity: model.activity(of: ws), showsDot: rail)
                } trailing: {
                    HStack(spacing: 6) {
                        WorkspaceCount(activity: model.activity(of: ws))
                        shortcut("⌃⌘\(index + 1)")
                    }
                }
                .overlay {
                    if targetedWorkspace == ws.id {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(theme.accent, lineWidth: 1.5)
                    }
                }
                .applying(if: !snapshot) { row in
                    row.draggable(AppModel.workspacePayload(ws.id))
                        .dropDestination(for: String.self) { items, _ in
                            model.handleDrop(items, ontoWorkspace: ws.id)
                        } isTargeted: { targetedWorkspace = $0 ? ws.id : (targetedWorkspace == ws.id ? nil : targetedWorkspace) }
                }
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
                if !rail {
                    FoldButton(folded: folded, label: ws.name) { toggleFolded(ws.id) }
                }
            }
            // Tabs: click to switch, drag to reorder or onto another workspace.
            if !rail && !folded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(ws.tabs) { tab in
                        SidebarTabRow(tab: tab, selected: model.route == .terminal && ws.id == model.state.activeWorkspaceID && tab.id == ws.activeTabID)
                    }
                }
                // A thin guide ties the tabs to their workspace.
                .overlay(alignment: .leading) {
                    Rectangle().fill(theme.hairline).frame(width: 1).padding(.leading, 22).padding(.vertical, 2)
                }
                .transition(.opacity)
            }
        }
        SidebarRow(title: "New Workspace", isSelected: false, collapsed: rail,
                   action: { model.addWorkspace() }) {
            icon("plus", selected: false)
        } trailing: { shortcut("⇧⌘N") }
        .overlay {
            if targetedNew {
                RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(theme.accent, lineWidth: 1.5)
            }
        }
        .applying(if: !snapshot) { row in
            row.dropDestination(for: String.self) { items, _ in
                model.handleDropOnNewWorkspace(items)
            } isTargeted: { targetedNew = $0 }
        }
    }

    private func icon(_ name: String, selected: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(selected ? theme.accent : theme.muted)
            .shadow(color: selected ? theme.accent.opacity(0.55) : .clear, radius: 5)
    }

    private func shortcut(_ keys: String) -> some View {
        Text(keys).font(.system(size: 11)).foregroundStyle(theme.faint)
    }
}

/// What is going on in a workspace's tabs: something running, or something that failed since you last looked.
enum WorkspaceActivity: Equatable {
    case none
    case running(Int)
    case failed
}

private struct WorkspaceBadge: View {
    @Environment(\.theme) private var theme
    let ws: Workspace
    let selected: Bool
    var activity: WorkspaceActivity = .none
    /// In the rail there is no room for a count, so the activity shows as a dot on the badge.
    var showsDot = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: ws.colorHex).opacity(selected ? 1 : 0.2))
            Text(String(ws.name.prefix(1)).uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Color.white : Color(hex: ws.colorHex))
        }
        .frame(width: 22, height: 22)
        .shadow(color: selected ? Color(hex: ws.colorHex).opacity(0.5) : .clear, radius: 6)
        .overlay(alignment: .topTrailing) {
            if showsDot, activity != .none {
                Circle().fill(activity == .failed ? Color.red : theme.accent)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().strokeBorder(theme.sidebar, lineWidth: 1.5))
                    .shadow(color: (activity == .failed ? Color.red : theme.accent).opacity(0.6), radius: 4)
                    .offset(x: 3, y: -3)
            }
        }
    }
}

/// Glowing count pill (tabs running) or a red dot (a command failed), at the end of a workspace row.
private struct WorkspaceCount: View {
    @Environment(\.theme) private var theme
    let activity: WorkspaceActivity

    var body: some View {
        switch activity {
        case .none:
            EmptyView()
        case .running(let n):
            Text("\(n)")
                .font(.system(size: 10.5, weight: .semibold)).monospacedDigit()
                .foregroundStyle(theme.onAccent)
                .padding(.horizontal, 6).frame(minWidth: 18, minHeight: 16)
                .background(theme.accent, in: Capsule())
                .shadow(color: theme.accent.opacity(0.45), radius: 5)
                .accessibilityLabel("\(n) running")
        case .failed:
            Circle().fill(Color.red).frame(width: 7, height: 7)
                .shadow(color: Color.red.opacity(0.6), radius: 4)
                .accessibilityLabel("A command failed")
        }
    }
}

/// The app mark with a soft glow, and a one-line description.
private struct Brand: View {
    @Environment(\.theme) private var theme
    let collapsed: Bool

    var body: some View {
        HStack(spacing: 11) {
            Group {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon).resizable().interpolation(.high).frame(width: 40, height: 40).padding(-4)
                }
            }
            .frame(width: 32, height: 32)
            .shadow(color: theme.accent.opacity(0.35), radius: 10)
            if !collapsed {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Better Terminal").font(.system(size: 14.5, weight: .semibold)).tracking(-0.2)
                    Text("Workspaces & terminals").font(.system(size: 10.5)).foregroundStyle(theme.muted)
                }
                .fixedSize()
                .transition(.opacity.animation(SidebarState.labelFade))
            }
        }
    }
}

/// A status dot and the version at the bottom, like a status bar.
private struct SidebarFooter: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let collapsed: Bool

    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).map { "v\($0)" } ?? "dev"
    }

    var body: some View {
        let running = model.runningCount
        HStack(spacing: 10) {
            Circle().fill(Color.green).frame(width: 7, height: 7)
                .shadow(color: Color.green.opacity(0.6), radius: 4)
            if !collapsed {
                Text(version).font(.system(size: 11.5)).foregroundStyle(theme.muted)
                Spacer(minLength: 4)
                if running > 0 {
                    Text("\(running) running").font(.system(size: 11.5)).foregroundStyle(theme.accent)
                } else {
                    Text("idle").font(.system(size: 11.5)).foregroundStyle(theme.faint)
                }
            }
        }
        .padding(.horizontal, collapsed ? 0 : 22)
        .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
        .frame(height: 34)
        .help(collapsed ? "\(version) · \(running == 0 ? "idle" : "\(running) running")" : "")
        .accessibilityElement(children: .combine)
    }
}

/// The round button on the sidebar's edge that collapses it to icons and back. Glows when hovered.
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
                .frame(width: 24, height: 24)
                .background(theme.groundColor, in: Circle())
                .overlay(Circle().strokeBorder(hovering ? theme.accent : theme.border))
                .overlay(Circle().strokeBorder(theme.accent.opacity(0.18), lineWidth: 3).padding(-2).opacity(hovering ? 1 : 0))
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .help(collapsed ? "Expand sidebar (⌃⌘S)" : "Collapse sidebar (⌃⌘S)")
        .accessibilityLabel(collapsed ? "Expand sidebar" : "Collapse sidebar")
    }
}

/// One sidebar entry: icon, title and trailing hint; as a rail, the icon alone with the title as a tooltip.
/// The selected row has a soft accent wash, a glowing icon and an indicator bar that slides in on the left edge.
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
                        .transition(.opacity.animation(SidebarState.labelFade))
                    Spacer(minLength: 4)
                    trailing().transition(.opacity.animation(SidebarState.labelFade))
                }
            }
            .padding(.leading, collapsed ? 0 : 12)
            .padding(.trailing, collapsed ? 0 : 10)
            .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
            .frame(height: 34)
            .background { rowBackground }
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(LinearGradient(colors: [theme.accent.opacity(0.7), theme.accent], startPoint: .top, endPoint: .bottom))
                        .frame(width: 3)
                        .padding(.vertical, 6)
                        .shadow(color: theme.accent.opacity(0.7), radius: 5)
                        .offset(x: -10)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(SidebarState.selection, value: isSelected)
        .help(collapsed ? title : "")
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var rowBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [theme.accent.opacity(0.16), theme.accent.opacity(0)],
                                     startPoint: .leading, endPoint: UnitPoint(x: 0.88, y: 0.5)))
        } else if hovering {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.hover)
        }
    }
}

/// A tab listed under its workspace in the sidebar.
private struct SidebarTabRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.sidebarSnapshot) private var snapshot
    let tab: TerminalTab
    let selected: Bool
    @State private var hovering = false
    @State private var dropTarget = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal").font(.system(size: 10.5)).foregroundStyle(selected ? theme.accent : theme.faint)
                .shadow(color: selected ? theme.accent.opacity(0.5) : .clear, radius: 4)
            Text(tab.title).font(.system(size: 12, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? Color.primary : theme.muted).lineLimit(1)
            Spacer(minLength: 0)
            TabStatusBadge(id: tab.id, selected: selected)
        }
        .padding(.leading, 40).padding(.trailing, 10)
        .frame(height: 28)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(LinearGradient(colors: [theme.accent.opacity(0.13), theme.accent.opacity(0)],
                                         startPoint: .leading, endPoint: UnitPoint(x: 0.9, y: 0.5)))
            } else if hovering {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(theme.hover.opacity(0.6))
            }
        }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(SidebarState.selection, value: selected)
        .overlay(alignment: .top) {
            if dropTarget { Capsule().fill(theme.accent).frame(height: 2).padding(.leading, 36).offset(y: -1) }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { model.select(tab: tab.id) }
        .simultaneousGesture(TapGesture(count: 2).onEnded { model.beginRenameTab(tab) })
        .applying(if: !snapshot) { row in
            row.onMiddleClick { model.requestCloseTab(tab.id) }
                .draggable(AppModel.tabPayload(tab.id))
                .dropDestination(for: String.self) { items, _ in
                    model.handleDrop(items, ontoTab: tab.id)
                } isTargeted: { dropTarget = $0 }
                .tabContextMenu(tab)
        }
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
