import Foundation

/// A colour scheme the user imported (iTerm `.itermcolors`, or Ghostty / kitty style `key = value` text).
public struct CustomTheme: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var background: String      // #RRGGBB
    public var foreground: String
    public var accent: String
    /// Up to 16 ANSI colours (#RRGGBB), index 0...15. May be empty.
    public var ansi: [String]

    public init(id: String = UUID().uuidString, name: String, background: String, foreground: String,
                accent: String, ansi: [String] = []) {
        self.id = id; self.name = name; self.background = background; self.foreground = foreground
        self.accent = accent; self.ansi = ansi
    }

    /// Dark schemes force the app into dark appearance so the derived UI colours stay readable.
    public var isDark: Bool { ThemeImport.luminance(hex: background) < 0.5 }
}

public enum ThemeImport {
    /// "#RRGGBB" from "#RGB", "RRGGBB", "0xRRGGBB", "rgb:rr/gg/bb" (case-insensitive). Nil if invalid.
    public static func normalizeHex(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.hasPrefix("rgb:") {
            let parts = s.dropFirst(4).split(separator: "/")
            guard parts.count == 3 else { return nil }
            s = parts.map { String($0.prefix(2)).count == 1 ? "0" + $0 : String($0.prefix(2)) }.joined()
        }
        for p in ["#", "0x"] where s.hasPrefix(p) { s = String(s.dropFirst(p.count)) }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, s.allSatisfy({ $0.isHexDigit }) else { return nil }
        return "#" + s.uppercased()
    }

    /// 0...1 relative brightness.
    public static func luminance(hex: String) -> Double {
        guard let (r, g, b) = rgb(hex) else { return 0 }
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    public static func rgb(_ hex: String) -> (Double, Double, Double)? {
        guard let h = normalizeHex(hex), let v = UInt32(h.dropFirst(), radix: 16) else { return nil }
        return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }

    /// Moves a colour toward white (`amount` > 0) or black (`amount` < 0), 0...1.
    public static func shifted(_ hex: String, by amount: Double) -> String {
        guard let (r, g, b) = rgb(hex) else { return hex }
        let target = amount >= 0 ? 1.0 : 0.0, t = min(abs(amount), 1)
        func ch(_ x: Double) -> Int { Int(((x + (target - x) * t) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", ch(r), ch(g), ch(b))
    }

    /// iTerm2 colour preset (plist). Components are 0...1 floats.
    public static func parseITerm(_ data: Data, name: String) -> CustomTheme? {
        guard let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else { return nil }
        func color(_ key: String) -> String? {
            guard let d = plist[key] as? [String: Any],
                  let r = (d["Red Component"] as? NSNumber)?.doubleValue,
                  let g = (d["Green Component"] as? NSNumber)?.doubleValue,
                  let b = (d["Blue Component"] as? NSNumber)?.doubleValue else { return nil }
            func c(_ x: Double) -> Int { Int((min(max(x, 0), 1) * 255).rounded()) }
            return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
        }
        guard let bg = color("Background Color"), let fg = color("Foreground Color") else { return nil }
        let ansi = (0..<16).compactMap { color("Ansi \($0) Color") }
        return CustomTheme(name: name, background: bg, foreground: fg,
                           accent: ansi.count > 4 ? ansi[4] : (color("Cursor Color") ?? fg),
                           ansi: ansi.count == 16 ? ansi : [])
    }

    /// Ghostty / kitty / WezTerm-ish text: `background = #1e1e2e`, `foreground #cdd6f4`, `palette = 0=#45475a`, `color0 #45475a`.
    public static func parseKeyValue(_ text: String, name: String) -> CustomTheme? {
        var bg: String?, fg: String?, cursor: String?
        var ansi = [String?](repeating: nil, count: 16)
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("//") { continue }
            let key: String, value: String
            if let eq = line.firstIndex(of: "=") {
                key = line[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
                value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            } else {
                let parts = line.split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" })
                guard parts.count == 2 else { continue }
                key = parts[0].lowercased(); value = parts[1].trimmingCharacters(in: .whitespaces)
            }
            switch key {
            case "background": bg = normalizeHex(value)
            case "foreground": fg = normalizeHex(value)
            case "cursor", "cursor-color": cursor = normalizeHex(value)
            case "palette":                       // "N=#rrggbb"
                let kv = value.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if kv.count == 2, let n = Int(kv[0]), (0..<16).contains(n) { ansi[n] = normalizeHex(kv[1]) }
            default:
                if key.hasPrefix("color"), let n = Int(key.dropFirst(5)), (0..<16).contains(n) { ansi[n] = normalizeHex(value) }
            }
        }
        guard let bg, let fg else { return nil }
        let full = ansi.compactMap { $0 }
        return CustomTheme(name: name, background: bg, foreground: fg,
                           accent: ansi[4] ?? cursor ?? fg, ansi: full.count == 16 ? full : [])
    }

    /// Picks the parser from the content: XML/binary plist → iTerm, otherwise key/value text.
    public static func parse(_ data: Data, name: String) -> CustomTheme? {
        if let t = parseITerm(data, name: name) { return t }
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return parseKeyValue(text, name: name)
    }
}

/// Pulls the output of the last command out of a terminal's text.
public enum CommandOutput {
    /// `snapshot` is the terminal text now; `startLength` is how many characters it had when the command started.
    /// Returns nil if the terminal scrolled so far that the start is gone (text shrank).
    public static func since(_ snapshot: String, startLength: Int, maxCharacters: Int = 200_000) -> String? {
        guard startLength >= 0, snapshot.count >= startLength else { return nil }
        let out = String(snapshot.dropFirst(startLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !out.isEmpty else { return nil }
        return out.count > maxCharacters ? String(out.suffix(maxCharacters)) : out
    }
}
