import SwiftUI
import BetterTerminalCore

/// First-launch tour. Reopen from Settings → About or the ⌘K palette.
struct Walkthrough: View {
    @Environment(\.theme) private var theme
    let onFinish: () -> Void
    @State private var page = 0
    @FocusState private var focused: Bool

    private struct Page { let title: String; let text: String }
    private let pages: [Page] = [
        Page(title: "Welcome to Better Terminal",
             text: "A fast, modern terminal for your Mac. Here is a one-minute tour of what it can do."),
        Page(title: "Workspaces and templates",
             text: "Keep each project in its own workspace, with its own tabs and layout. Switch from the sidebar or with ⌃⌘1–9, drag to reorder, middle-click a tab to close it. Save a setup as a template and open it again in one click."),
        Page(title: "Pane layouts and splits",
             text: "Tabs fill a grid: 1×2, 2×1, 2×2 or your own (⌥⌘L). Split the current pane with ⌘D or ⇧⌘D, swap panes by dragging a header onto another, and move between them with ⌘ and the arrow keys. The grid shrinks to fit when you close tabs."),
        Page(title: "History for every tab",
             text: "Press ⇧⌘H or the clock button on a pane. Type to search, ↑↓ to move, ⏎ to put the command at the prompt, ⌘⏎ to run it."),
        Page(title: "Command palette",
             text: "Press ⌘K to jump anywhere. Your last three commands are at the top. Press → for the Commands tab: the last 30 commands from every terminal, searchable. ← goes back to Actions."),
        Page(title: "Find, links and right-click",
             text: "⌘F searches the scrollback. Links underline when you hover them, and right-click gives you copy, paste, open link, find, split and more. ⌥⌘C copies the last command's output."),
        Page(title: "Know when it's done",
             text: "A spinner shows while a command runs and a red dot marks a failed one. When a long command finishes in another tab, you get a notification. ⌥⌘I broadcasts what you type to every pane."),
        Page(title: "Quick terminal",
             text: "Turn it on in Settings, then press ⌃` from any app to drop a terminal down from the top of the screen. Press it again to hide. You can choose another key."),
        Page(title: "Make it yours",
             text: "Pick a soft colour theme, or import an iTerm2, Ghostty or kitty theme. Choose any monospaced font. Every feature is explained in the documentation on the website.")
    ]
    private var last: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { }
            VStack(spacing: 0) {
                hero
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .background(theme.card)
                VStack(spacing: 10) {
                    Text(pages[page].title).font(.system(size: 22, weight: .semibold))
                    Text(pages[page].text).font(.system(size: 13.5)).foregroundStyle(theme.muted)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 460)
                }
                .id(page)
                .transition(.opacity)
                .padding(.top, 22).padding(.horizontal, 32)
                Spacer(minLength: 16)
                HStack {
                    Button("Skip") { onFinish() }.buttonStyle(.plain).foregroundStyle(theme.muted)
                        .opacity(last ? 0 : 1)
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(pages.indices, id: \.self) { i in
                            Circle().fill(i == page ? theme.accent : theme.track).frame(width: 7, height: 7)
                        }
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        if page > 0 { PillButton(title: "Back") { go(-1) } }
                        PillButton(title: last ? "Get Started" : "Next", prominent: true) { last ? onFinish() : go(1) }
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 20)
            }
            .frame(width: 580, height: 510)
            .background(theme.groundColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(theme.border))
            .shadow(color: .black.opacity(0.3), radius: 30, y: 12)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .focusable()
            .focused($focused)
            .focusEffectDisabled()
            .onKeyPress(.rightArrow) { go(1); return .handled }
            .onKeyPress(.leftArrow) { go(-1); return .handled }
            .onKeyPress(.return) { last ? onFinish() : go(1); return .handled }
            .onKeyPress(.escape) { onFinish(); return .handled }
            .onAppear { focused = true }
        }
        .animation(.easeOut(duration: 0.2), value: page)
    }

    private func go(_ delta: Int) { page = min(max(page + delta, 0), pages.count - 1) }

    @ViewBuilder private var hero: some View {
        switch page {
        case 0:
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon).resizable().interpolation(.high).frame(width: 130, height: 130)
            }
        case 1:
            VStack(alignment: .leading, spacing: 6) {
                mockRow("A", "App", Color(hex: "#0A84FF"), selected: true)
                mockRow("W", "Website", Color(hex: "#30B26B"), selected: false)
                mockRow("D", "Docs", Color(hex: "#FF7A45"), selected: false)
            }
            .frame(width: 220)
        case 2:
            HStack(spacing: 12) {
                ForEach([PaneLayout(rows: 1, columns: 2), PaneLayout(rows: 2, columns: 1),
                         PaneLayout(rows: 2, columns: 2), PaneLayout(rows: 3, columns: 1)]) { l in
                    LayoutThumb(layout: l, selected: l == PaneLayout(rows: 2, columns: 2))
                }
            }
        case 3:
            VStack(spacing: 4) {
                historyRow("git push origin main", ok: true, selected: false)
                historyRow("swift test", ok: false, selected: true)
                historyRow("brew install xcodegen", ok: true, selected: false)
            }
            .frame(width: 280)
        case 4:
            HStack(spacing: 10) {
                keycap("⌘"); keycap("K")
                Text("Search anything").foregroundStyle(theme.muted)
                keycap("→")
                Text("Commands").foregroundStyle(theme.muted)
            }
        case 5:
            HStack(spacing: 10) {
                keycap("⌘"); keycap("F")
                Text("Find in terminal").foregroundStyle(theme.muted)
            }
        case 6:
            HStack(spacing: 22) {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("running").foregroundStyle(theme.muted) }
                HStack(spacing: 8) { Circle().fill(Color.red).frame(width: 9, height: 9); Text("failed").foregroundStyle(theme.muted) }
                HStack(spacing: 8) { Image(systemName: "bell.badge").foregroundStyle(theme.accent); Text("finished").foregroundStyle(theme.muted) }
            }
        case 7:
            HStack(spacing: 10) {
                keycap("⌃"); keycap("`")
                Text("from any app").foregroundStyle(theme.muted)
            }
        default:
            HStack(spacing: 10) {
                ForEach(Array(Theme.all.prefix(6))) { t in
                    Circle().fill(t.accent).frame(width: 30, height: 30)
                        .overlay(Circle().strokeBorder(theme.border))
                }
            }
        }
    }

    private func mockRow(_ letter: String, _ name: String, _ color: Color, selected: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color.opacity(selected ? 1 : 0.25))
                Text(letter).font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? Color.white : color)
            }
            .frame(width: 22, height: 22)
            Text(name).font(.system(size: 13, weight: selected ? .semibold : .regular))
            Spacer()
        }
        .padding(.horizontal, 10).frame(height: 32)
        .background(selected ? theme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func historyRow(_ cmd: String, ok: Bool, selected: Bool) -> some View {
        HStack(spacing: 8) {
            Circle().fill(ok ? Color.green : Color.red).frame(width: 6, height: 6)
            Text(cmd).font(.system(.callout, design: .monospaced)).lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(selected ? theme.selection : theme.groundColor.opacity(0.6),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func keycap(_ s: String) -> some View {
        Text(s).font(.system(size: 20, weight: .medium, design: .rounded))
            .frame(width: 44, height: 44)
            .background(theme.cardRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(theme.border))
    }
}
