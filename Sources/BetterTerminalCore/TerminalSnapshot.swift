import Foundation

/// Saves and replays a terminal's text so a relaunch shows what was on screen. Plain text only (no colours);
/// running programs cannot be revived, a fresh shell starts below the restored text.
public enum TerminalText {
    public static let defaultMaxLines = 2000

    /// Cleans text read from a terminal buffer before it is stored: drops control characters (ESC, CR…),
    /// strips trailing spaces, removes trailing blank lines and keeps only the last `maxLines` lines.
    /// Returns "" when nothing but blank lines remain.
    public static func prepare(_ raw: String, maxLines: Int = defaultMaxLines) -> String {
        let unified = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let cleaned = String(String.UnicodeScalarView(unified.unicodeScalars.filter {
            $0 == "\n" || $0 == "\t" || ($0.value >= 0x20 && $0.value != 0x7F)
        }))
        var lines = cleaned.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            var s = String(line)
            while s.last == " " || s.last == "\t" { s.removeLast() }
            return s
        }
        while let last = lines.last, last.isEmpty { lines.removeLast() }
        if lines.count > maxLines { lines = Array(lines.suffix(maxLines)) }
        return lines.joined(separator: "\n")
    }

    /// What to save for a terminal after the user pressed "Clear": only text produced after the clear.
    /// `baseline` is the prepared text the terminal held at that moment. If the buffer still starts with it,
    /// that part is dropped; if it only equals it, nothing is saved. (If the buffer has scrolled past the baseline,
    /// the text is kept as is.)
    public static func afterClear(_ text: String, baseline: String) -> String {
        guard !baseline.isEmpty else { return text }
        if text == baseline { return "" }
        if text.hasPrefix(baseline) {
            return prepare(String(text.dropFirst(baseline.count)).trimmingCharacters(in: .newlines))
        }
        return text
    }

    /// Bytes to feed a fresh terminal to show the saved text, followed by a dim divider line.
    /// Empty input gives "" (nothing is replayed).
    public static func replayPayload(_ saved: String) -> String {
        let body = saved.trimmingCharacters(in: .newlines)
        guard !body.isEmpty else { return "" }
        let crlf = body.replacingOccurrences(of: "\n", with: "\r\n")
        return crlf + "\r\n\u{1B}[2m── restored from previous session ──\u{1B}[0m\r\n"
    }
}
