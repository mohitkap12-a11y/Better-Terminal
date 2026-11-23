import Foundation

/// Shell hooks that report each command, its exit code and the cwd to the terminal
/// via private OSC escape sequences (no output is captured, commands only):
///   OSC 7777 ; base64(command)   -- command about to run
///   OSC 133 ; D ; <exit>         -- command finished
///   OSC 7779 ; base64(cwd)       -- prompt shown, current directory
public enum ShellIntegration {
    public enum Kind: Sendable { case zsh, bash, fish, other }

    public static func kind(forShellPath path: String) -> Kind {
        switch (path as NSString).lastPathComponent {
        case "zsh": return .zsh
        case "bash": return .bash
        case "fish": return .fish
        default: return .other
        }
    }

    // MARK: Scripts
    static let zshenv = #"""
    [[ -n "$BT_USER_ZDOTDIR" && -f "$BT_USER_ZDOTDIR/.zshenv" ]] && source "$BT_USER_ZDOTDIR/.zshenv"
    """#

    static let zprofile = #"""
    [[ -n "$BT_USER_ZDOTDIR" && -f "$BT_USER_ZDOTDIR/.zprofile" ]] && source "$BT_USER_ZDOTDIR/.zprofile"
    """#

    static let zshrc = #"""
    # Better-Terminal shell integration (zsh)
    [[ -n "$BT_USER_ZDOTDIR" && -f "$BT_USER_ZDOTDIR/.zshrc" ]] && source "$BT_USER_ZDOTDIR/.zshrc"
    ZDOTDIR="$BT_USER_ZDOTDIR"
    [[ -n "$BT_START_DIR" && -d "$BT_START_DIR" ]] && cd "$BT_START_DIR"
    autoload -Uz add-zsh-hook
    __bt_b64() { printf %s "$1" | base64 | tr -d '\n'; }
    __bt_preexec() { printf '\033]7777;%s\007' "$(__bt_b64 "$1")"; }
    __bt_precmd() {
      local c=$?
      printf '\033]133;D;%s\007' "$c"
      printf '\033]7779;%s\007' "$(__bt_b64 "$PWD")"
    }
    add-zsh-hook preexec __bt_preexec
    add-zsh-hook precmd __bt_precmd
    """#

    static let bashrc = #"""
    # Better-Terminal shell integration (bash)
    if [ -f "$HOME/.bash_profile" ]; then . "$HOME/.bash_profile"; elif [ -f "$HOME/.bashrc" ]; then . "$HOME/.bashrc"; fi
    [ -n "$BT_START_DIR" ] && [ -d "$BT_START_DIR" ] && cd "$BT_START_DIR"
    __bt_b64() { printf %s "$1" | base64 | tr -d '\n'; }
    __bt_precmd() {
      local c=$?
      printf '\033]133;D;%s\007' "$c"
      printf '\033]7779;%s\007' "$(__bt_b64 "$PWD")"
      return $c
    }
    __bt_arm() { __bt_ready=1; }
    __bt_debug() {
      [ -n "$__bt_ready" ] || return 0
      case "$BASH_COMMAND" in __bt_*) return 0;; esac
      __bt_ready=
      local line
      line="$(HISTTIMEFORMAT= history 1 | sed 's/^ *[0-9]* *//')"
      printf '\033]7777;%s\007' "$(__bt_b64 "${line:-$BASH_COMMAND}")"
    }
    trap '__bt_debug' DEBUG
    PROMPT_COMMAND="__bt_precmd${PROMPT_COMMAND:+;$PROMPT_COMMAND};__bt_arm"
    """#

    static let fish = #"""
    # Better-Terminal shell integration (fish)
    if test -n "$BT_START_DIR"; and test -d "$BT_START_DIR"; cd "$BT_START_DIR"; end
    function __bt_preexec --on-event fish_preexec
      printf '\033]7777;%s\007' (printf %s "$argv[1]" | base64 | tr -d '\n')
    end
    function __bt_postexec --on-event fish_postexec
      set -l c $status
      printf '\033]133;D;%s\007' $c
    end
    function __bt_prompt --on-event fish_prompt
      printf '\033]7779;%s\007' (printf %s "$PWD" | base64 | tr -d '\n')
    end
    """#

    /// Writes hook scripts under `dir`. Safe to call on every launch.
    public static func install(into dir: URL) throws {
        let fm = FileManager.default
        for sub in ["zsh", "bash", "fish"] {
            try fm.createDirectory(at: dir.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
        try zshenv.write(to: dir.appendingPathComponent("zsh/.zshenv"), atomically: true, encoding: .utf8)
        try zprofile.write(to: dir.appendingPathComponent("zsh/.zprofile"), atomically: true, encoding: .utf8)
        try zshrc.write(to: dir.appendingPathComponent("zsh/.zshrc"), atomically: true, encoding: .utf8)
        try bashrc.write(to: dir.appendingPathComponent("bash/bashrc.sh"), atomically: true, encoding: .utf8)
        try fish.write(to: dir.appendingPathComponent("fish/bt.fish"), atomically: true, encoding: .utf8)
    }

    public struct LaunchSpec: Sendable { public var args: [String]; public var env: [String: String] }

    public static func launchSpec(shell: String, cwd: String, baseEnv: [String: String], integrationDir: URL) -> LaunchSpec {
        var env = baseEnv
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["TERM_PROGRAM"] = "BetterTerminal"
        env["BT_START_DIR"] = cwd
        switch kind(forShellPath: shell) {
        case .zsh:
            env["BT_USER_ZDOTDIR"] = baseEnv["ZDOTDIR"] ?? baseEnv["HOME"] ?? NSHomeDirectory()
            env["ZDOTDIR"] = integrationDir.appendingPathComponent("zsh").path
            return LaunchSpec(args: ["-l"], env: env)
        case .bash:
            return LaunchSpec(args: ["--rcfile", integrationDir.appendingPathComponent("bash/bashrc.sh").path], env: env)
        case .fish:
            return LaunchSpec(args: ["--init-command", "source " + integrationDir.appendingPathComponent("fish/bt.fish").path], env: env)
        case .other:
            return LaunchSpec(args: ["-l"], env: env)
        }
    }

    /// Single-quotes a string for fish (paths like "Application Support" contain spaces).
    public static func fishQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'") + "'"
    }

    // MARK: Payload parsing
    public static func decodeBase64(_ s: String) -> String? {
        guard let d = Data(base64Encoded: s.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return String(data: d, encoding: .utf8)
    }

    /// Accepts "D;0", "0", " 1".
    public static func parseExit(_ s: String) -> Int32? {
        let part = s.split(separator: ";").last.map(String.init) ?? s
        return Int32(part.trimmingCharacters(in: .whitespaces))
    }
}

/// Turns the shell's start/finish events into history entries.
public struct CommandTracker: Sendable {
    public var cwd: String
    private var pending: (command: String, start: Date, cwd: String)?

    public init(cwd: String) { self.cwd = cwd }

    public mutating func commandStarted(_ command: String, at date: Date = Date()) {
        let c = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty else { return }
        pending = (c, date, cwd)
    }

    public mutating func commandFinished(exitCode: Int32?, at date: Date = Date()) -> HistoryEntry? {
        defer { pending = nil }
        guard let p = pending else { return nil }
        return HistoryEntry(command: p.command, cwd: p.cwd, exitCode: exitCode,
                            startedAt: p.start, duration: date.timeIntervalSince(p.start))
    }
}

/// Builds the bytes sent to the shell when inserting/running text at the prompt.
public enum PromptInput {
    static let clearLine = "\u{15}"          // Ctrl-U
    static let pasteStart = "\u{1B}[200~", pasteEnd = "\u{1B}[201~"

    /// Removes control characters (ESC, CR, etc.) that could end a paste early or execute input.
    /// Keeps newline and tab. CRLF/CR become LF.
    public static func sanitize(_ text: String) -> String {
        let unified = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return String(String.UnicodeScalarView(unified.unicodeScalars.filter {
            $0 == "\n" || $0 == "\t" || ($0.value >= 0x20 && $0.value != 0x7F)
        }))
    }

    /// Text to type at the prompt WITHOUT executing it.
    /// Multi-line text uses bracketed paste so embedded newlines stay in the edit buffer.
    /// If the shell has not enabled bracketed paste, lines are joined with "; " (never a raw newline).
    public static func insertPayload(_ text: String, bracketedPaste: Bool) -> String {
        let clean = sanitize(text)
        guard clean.contains("\n") else { return clearLine + clean }
        if bracketedPaste { return clearLine + pasteStart + clean + pasteEnd }
        let joined = clean.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: "; ")
        return clearLine + joined
    }

    /// Same as insert, followed by Enter.
    public static func runPayload(_ text: String, bracketedPaste: Bool) -> String {
        insertPayload(text, bracketedPaste: bracketedPaste) + "\r"
    }
}
