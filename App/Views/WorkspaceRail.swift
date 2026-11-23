import SwiftUI
import BetterTerminalCore

struct WorkspaceRail: View {
    @Environment(AppModel.self) private var model
    @State private var renaming: Workspace?
    @State private var newName = ""
    @State private var deleting: Workspace?

    private let colors = ["#0A84FF", "#30B26B", "#FF7A45", "#8E6CF0", "#FF375F", "#64D2FF"]

    var body: some View {
        VStack(spacing: Metrics.s2) {
            Spacer().frame(height: Metrics.s6)   // clears traffic lights
            ForEach(Array(model.state.workspaces.enumerated()), id: \.element.id) { index, ws in
                WorkspaceButton(ws: ws, selected: ws.id == model.state.activeWorkspaceID, index: index)
                    .onTapGesture { model.state.activeWorkspaceID = ws.id }
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
            Button { model.addWorkspace() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.secondary)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: Metrics.radiusCard))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New workspace")
            .help("New workspace (⇧⌘N)")
            Spacer()
            SettingsLink {
                Image(systemName: "gearshape").frame(width: 36, height: 36).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
            .help("Settings (⌘,)")
        }
        .padding(.horizontal, Metrics.s2)
        .padding(.bottom, Metrics.s3)
        .frame(width: 56)
        .background(.regularMaterial)
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
}

private struct WorkspaceButton: View {
    let ws: Workspace
    let selected: Bool
    let index: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Metrics.radiusCard)
                .fill(Color(hex: ws.colorHex).opacity(selected ? 1 : 0.18))
            Text(String(ws.name.prefix(1)).uppercased())
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(selected ? Color.white : Color(hex: ws.colorHex))
        }
        .frame(width: 36, height: 36)
        .overlay(alignment: .leading) {
            Capsule().fill(.primary).frame(width: 3, height: selected ? 20 : 0)
                .offset(x: -Metrics.s2 - 1)
                .opacity(selected ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.15), value: selected)
        .contentShape(Rectangle())
        .help("\(ws.name) (⌃⌘\(index + 1))")
        .accessibilityElement()
        .accessibilityLabel(ws.name)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
