import SwiftUI
import BetterTerminalCore

/// One terminal pane = one tab. Hosts the live terminal session.
struct PaneView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    let tab: TerminalTab
    let focused: Bool

    var body: some View {
        let session = model.session(for: tab)
        VStack(spacing: 0) {
            header(session)
            Divider()
            TerminalHost(session: session, theme: theme, scheme: scheme, fontSize: model.state.terminalFontSize)
        }
        .background(theme.background(scheme))
        .overlay(alignment: .top) {
            if focused { Rectangle().fill(theme.accent).frame(height: 2) }
        }
        .onAppear { if focused { session.focus() } }
        .onChange(of: focused) { if focused { session.focus() } }
    }

    private func header(_ session: TerminalSession) -> some View {
        HStack(spacing: Metrics.s2) {
            Text(tab.cwd.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            Button { model.historyOpenTab = (model.historyOpenTab == tab.id ? nil : tab.id) } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Command history")
            .help("Command history (⇧⌘H)")
            .popover(isPresented: Binding(get: { model.historyOpenTab == tab.id },
                                          set: { if !$0 { model.historyOpenTab = nil } }),
                     arrowEdge: .bottom) {
                HistoryDrawer(tab: tab) { cmd, runNow in
                    model.historyOpenTab = nil
                    if runNow { session.run(cmd) } else { session.insert(cmd) }
                    session.focus()
                }
            }
        }
        .padding(.horizontal, Metrics.s3)
        .frame(height: 28)
        .contentShape(Rectangle())
        .onTapGesture { model.mutateActive { $0.activeTabID = tab.id }; session.focus() }
    }
}
