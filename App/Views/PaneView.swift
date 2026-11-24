import SwiftUI
import BetterTerminalCore

/// One terminal pane = one tab. Hosts the live terminal session.
struct PaneView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    let tab: TerminalTab
    let focused: Bool
    @State private var pulse: Double = 0
    @State private var paneDropTarget = false

    var body: some View {
        let session = model.session(for: tab)
        VStack(spacing: 0) {
            header(session)
            Divider()
            TerminalHost(session: session, theme: theme, scheme: scheme, fontSize: model.state.terminalFontSize,
                         fontFamily: model.state.terminalFontFamily)
        }
        .background(theme.terminalBackground(scheme))
        .overlay(alignment: .top) {
            if focused { Rectangle().fill(theme.accent).frame(height: 2) }
        }
        .overlay(alignment: .topTrailing) {
            if focused && model.findOpen { FindBar().padding(.top, 36).padding(.trailing, Metrics.s3) }
        }
        .overlay {
            if paneDropTarget {
                RoundedRectangle(cornerRadius: 4).strokeBorder(theme.accent, lineWidth: 3).allowsHitTesting(false)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            model.handleDrop(items, ontoPane: tab.id)
        } isTargeted: { paneDropTarget = $0 }
        .overlay {
            // Subtle highlight when you arrive here with ⌘+arrow: a soft wash and an accent edge that fade out.
            ZStack {
                Rectangle().fill(theme.accent.opacity(0.08))
                Rectangle().strokeBorder(theme.accent.opacity(0.85), lineWidth: 2.5)
            }
            .opacity(pulse)
            .allowsHitTesting(false)
        }
        .onChange(of: model.flashID) {
            guard model.flashTab == tab.id else { return }
            pulse = 1
            withAnimation(.easeOut(duration: 0.75)) { pulse = 0 }
        }
        .onAppear { if focused { session.focus() } }
        .onChange(of: focused) { if focused { session.focus() } }
    }

    private func header(_ session: TerminalSession) -> some View {
        HStack(spacing: Metrics.s2) {
            Image(systemName: "line.3.horizontal").font(.system(size: 9)).foregroundStyle(.tertiary)
                .help("Drag onto another pane to swap them")
            Text(tab.cwd.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
                .contextMenu {
                    Button("Reveal in Finder") { model.revealInFinder(tab.cwd) }
                    if model.hasEditor { Button("Open in VS Code") { model.openInEditor(tab.cwd) } }
                    Button("Copy Path") {
                        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(tab.cwd, forType: .string)
                    }
                    Divider()
                    Button("Copy Last Output") { model.copyLastOutput() }
                }
            TabStatusBadge(id: tab.id, selected: focused)
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
        .onTapGesture { model.mutateActive { $0.activeTabID = tab.id }; model.failedTabs.remove(tab.id); session.focus() }
        .draggable(AppModel.panePayload(tab.id))
        .onMiddleClick { model.requestCloseTab(tab.id) }
    }
}
