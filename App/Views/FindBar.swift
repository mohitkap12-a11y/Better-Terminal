import SwiftUI

/// ⌘F: search the scrollback of the active pane. ⏎ next, ⇧⏎ previous, esc closes.
struct FindBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        HStack(spacing: Metrics.s2) {
            Image(systemName: "magnifyingglass").foregroundStyle(theme.muted)
            TextField("Find in terminal", text: $model.findQuery)
                .textFieldStyle(.plain)
                .frame(width: 180)
                .focused($focused)
                .onSubmit { model.findNext(forward: !NSEvent.modifierFlags.contains(.shift)) }
                .onChange(of: model.findQuery) { model.findNext() }
                .onKeyPress(.escape) { model.closeFind(); return .handled }
            if model.findMissed {
                Text("No matches").font(.caption).foregroundStyle(.red)
            }
            Button { model.findNext(forward: false) } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.borderless).accessibilityLabel("Previous match").help("Previous (⇧⌘G)")
            Button { model.findNext() } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.borderless).accessibilityLabel("Next match").help("Next (⌘G)")
            Button { model.closeFind() } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless).accessibilityLabel("Close find").help("Close (esc)")
        }
        .padding(.horizontal, Metrics.s3).padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(theme.border))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .onAppear { focused = true }
    }
}

/// Spinner while a command runs; red dot when the last command failed in a tab you have not looked at since.
struct TabStatusBadge: View {
    @Environment(AppModel.self) private var model
    let id: UUID
    let selected: Bool

    var body: some View {
        if model.runningTabs.contains(id) {
            ProgressView().controlSize(.mini).scaleEffect(0.7).frame(width: 12, height: 12)
                .accessibilityLabel("Command running")
        } else if model.failedTabs.contains(id) && !selected {
            Circle().fill(Color.red).frame(width: 7, height: 7).accessibilityLabel("Last command failed")
        }
    }
}
