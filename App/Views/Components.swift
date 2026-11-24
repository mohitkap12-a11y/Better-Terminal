import SwiftUI
import BetterTerminalCore

/// Page title + one line about the page.
struct PageHeader: View {
    @Environment(\.theme) private var theme
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 24, weight: .semibold))
            Text(subtitle).font(.system(size: 13)).foregroundStyle(theme.muted)
        }
    }
}

/// The card that settings sections sit in, split by hairlines.
struct SectionCard<Content: View>: View {
    @Environment(\.theme) private var theme
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, 22)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(theme.border))
    }
}

/// One section: title and a line about it on the left, its rows on the right.
struct SettingsSection<Content: View>: View {
    @Environment(\.theme) private var theme
    let title: String
    let subtitle: String
    var first = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                Text(subtitle).font(.system(size: 11.5)).foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 190, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 20)
        .overlay(alignment: .top) { if !first { Rectangle().fill(theme.hairline).frame(height: 1) } }
    }
}

/// One setting: title and hint on the left, the control on the right.
struct SettingsRow<Control: View>: View {
    @Environment(\.theme) private var theme
    let title: String
    let subtitle: String
    var showsDivider = true
    @ViewBuilder var control: () -> Control

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsDivider { Rectangle().fill(theme.hairline).frame(height: 1).padding(.bottom, 2) }
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .medium))
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 560, alignment: .leading)
                Spacer(minLength: 12)
                control()
            }
        }
        .padding(.vertical, 6)
    }
}

/// A row of selectable values, a segmented control in the app's style.
struct ChoiceChips<Value: Hashable>: View {
    @Environment(\.theme) private var theme
    let values: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(values, id: \.self) { value in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = value }
                } label: {
                    Text(title(value))
                        .font(.system(size: 12, weight: selection == value ? .semibold : .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundStyle(Color.primary)
                        .background(selection == value ? theme.selection : theme.card,
                                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(selection == value ? theme.accent.opacity(0.6) : theme.border))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
    }
}

/// Compact bordered button used in settings rows.
struct PillButton: View {
    @Environment(\.theme) private var theme
    let title: String
    var prominent = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .foregroundStyle(prominent ? theme.onAccent : Color.primary)
                .background(prominent ? theme.accent : theme.cardRaised,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

/// Right-click menu for a tab: rename, move to another workspace, close.
struct TabContextMenu: ViewModifier {
    @Environment(AppModel.self) private var model
    let tab: TerminalTab

    func body(content: Content) -> some View {
        content.contextMenu {
            Button("Rename…") { model.beginRenameTab(tab) }
            Menu("Move to Workspace") {
                ForEach(model.state.workspaces) { ws in
                    if !ws.tabs.contains(where: { $0.id == tab.id }) {
                        Button(ws.name) { model.moveTab(tab.id, toWorkspace: ws.id) }
                    }
                }
                Divider()
                Button("New Workspace") { model.moveTabToNewWorkspace(tab.id) }
            }
            Divider()
            Button("Close Tab", role: .destructive) { model.closeTab(tab.id) }
                .disabled(!model.canCloseTab(tab.id))
        }
    }
}

extension View {
    func tabContextMenu(_ tab: TerminalTab) -> some View { modifier(TabContextMenu(tab: tab)) }
}
