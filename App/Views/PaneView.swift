import SwiftUI
import BetterTerminalCore

/// Temporary terminal pane: runs one command at a time via the user's shell.
/// Replaced by the libghostty-backed TerminalEngine view (roadmap step 3).
struct PaneView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    let tab: TerminalTab
    let focused: Bool

    @State private var transcript = ""
    @State private var input = ""
    @State private var running = false
    @State private var showHistory = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    Text(transcript.isEmpty ? " " : transcript)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(theme.foreground(scheme))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Metrics.s3)
                    Color.clear.frame(height: 1).id("end")
                }
                .onChange(of: transcript) { proxy.scrollTo("end") }
            }
            HStack(spacing: Metrics.s2) {
                Text("❯").foregroundStyle(theme.accent)
                TextField("Run a command", text: $input)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($inputFocused)
                    .disabled(running)
                    .onSubmit(submit)
                if running { ProgressView().controlSize(.small) }
            }
            .padding(Metrics.s3)
            .background(theme.foreground(scheme).opacity(0.05))
        }
        .background(theme.background(scheme))
        .overlay(alignment: .top) {
            if focused { Rectangle().fill(theme.accent).frame(height: 2) }
        }
        .contentShape(Rectangle())
        .onTapGesture { model.mutateActive { $0.activeTabID = tab.id }; inputFocused = true }
        .onAppear { if focused { inputFocused = true } }
    }

    private var header: some View {
        HStack(spacing: Metrics.s2) {
            Text(tab.cwd.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            Button { showHistory.toggle() } label: { Image(systemName: "clock.arrow.circlepath") }
                .buttonStyle(.borderless)
                .accessibilityLabel("Command history")
                .help("Command history")
                .popover(isPresented: $showHistory, arrowEdge: .bottom) {
                    HistoryDrawer(tab: tab) { cmd, runNow in
                        showHistory = false
                        input = cmd
                        if runNow { submit() } else { inputFocused = true }
                    }
                }
        }
        .padding(.horizontal, Metrics.s3)
        .frame(height: 28)
    }

    private func submit() {
        let cmd = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty, !running else { return }
        input = ""; running = true
        transcript += "❯ \(cmd)\n"
        let cwd = tab.cwd, shell = tab.shell, tabID = tab.id
        Task {
            let started = Date()
            let (out, code, newCwd) = await ShellRunner.run(cmd, shell: shell, cwd: cwd)
            transcript += out + (out.hasSuffix("\n") || out.isEmpty ? "" : "\n")
            if let newCwd { model.updateCwd(tab: tabID, to: newCwd) }
            model.record(HistoryEntry(command: cmd, cwd: cwd, exitCode: code, startedAt: started,
                                      duration: Date().timeIntervalSince(started)), tab: tabID)
            running = false
            inputFocused = true
        }
    }
}

enum ShellRunner {
    /// Handles `cd` natively; everything else runs via `shell -lc`.
    static func run(_ cmd: String, shell: String, cwd: String) async -> (String, Int32, String?) {
        if cmd == "cd" || cmd.hasPrefix("cd ") {
            let arg = cmd.dropFirst(2).trimmingCharacters(in: .whitespaces)
            let target = arg.isEmpty ? NSHomeDirectory()
                : (arg.hasPrefix("~") ? (arg as NSString).expandingTildeInPath
                : (arg.hasPrefix("/") ? arg : (cwd as NSString).appendingPathComponent(arg)))
            let resolved = (target as NSString).standardizingPath
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir), isDir.boolValue {
                return ("", 0, resolved)
            }
            return ("cd: no such directory: \(arg)\n", 1, nil)
        }
        return await Task.detached(priority: .userInitiated) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: shell)
            p.arguments = ["-lc", cmd]
            p.currentDirectoryURL = URL(fileURLWithPath: cwd)
            let pipe = Pipe()
            p.standardOutput = pipe; p.standardError = pipe
            do { try p.run() } catch { return ("\(error.localizedDescription)\n", 127, nil as String?) }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return (String(decoding: data, as: UTF8.self), p.terminationStatus, nil as String?)
        }.value
    }
}
