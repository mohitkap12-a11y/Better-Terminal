import SwiftUI
import AppKit

extension Color {
    /// Fixed sRGB colour from "#RRGGBB" / "#RGB".
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }

    /// Colour that follows the appearance of the view it is drawn in.
    static func adaptive(light: String, dark: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
    }
}

/// A colour theme: a few base colours per appearance; everything else (cards, borders, hover, selection,
/// muted text) is derived from them, so every theme stays consistent and light on the eyes.
struct Theme: Identifiable, Hashable {
    let id: String
    let name: String
    let ground: (light: String, dark: String)
    let sidebarBase: (light: String, dark: String)
    let termBg: (light: String, dark: String)
    let termFg: (light: String, dark: String)
    let accentBase: (light: String, dark: String)

    static func == (l: Theme, r: Theme) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    // Base surfaces
    var groundColor: Color { .adaptive(light: ground.light, dark: ground.dark) }
    var sidebar: Color { .adaptive(light: sidebarBase.light, dark: sidebarBase.dark) }
    var accent: Color { .adaptive(light: accentBase.light, dark: accentBase.dark) }
    var onAccent: Color { .white }

    // Derived tokens (overlays of the primary text colour, so they work on any ground)
    var card: Color { Color.primary.opacity(0.045) }
    var cardRaised: Color { Color.primary.opacity(0.08) }
    var hover: Color { Color.primary.opacity(0.06) }
    var border: Color { Color.primary.opacity(0.10) }
    var hairline: Color { Color.primary.opacity(0.07) }
    var track: Color { Color.primary.opacity(0.08) }
    var selection: Color { accent.opacity(0.16) }
    var muted: Color { Color.primary.opacity(0.62) }
    var faint: Color { Color.primary.opacity(0.40) }

    // Terminal surface
    func terminalBackground(_ s: ColorScheme) -> Color { Color(hex: s == .dark ? termBg.dark : termBg.light) }
    func terminalForeground(_ s: ColorScheme) -> Color { Color(hex: s == .dark ? termFg.dark : termFg.light) }

    static let all: [Theme] = [
        Theme(id: "default", name: "Default",
              ground: ("#FBFBFC", "#161618"), sidebarBase: ("#F1F1F3", "#1D1D20"),
              termBg: ("#FFFFFF", "#131315"), termFg: ("#1D1D1F", "#E8E8EA"), accentBase: ("#0A84FF", "#4DA3FF")),
        Theme(id: "mist", name: "Mist",
              ground: ("#F5F7FA", "#1A1D21"), sidebarBase: ("#EBEFF4", "#20242A"),
              termBg: ("#FAFBFD", "#16191D"), termFg: ("#243040", "#D5DCE5"), accentBase: ("#3B7DD8", "#6AA6F0")),
        Theme(id: "sage", name: "Sage",
              ground: ("#F4F7F3", "#1B1F1C"), sidebarBase: ("#E9EFE8", "#212622"),
              termBg: ("#FAFCF9", "#171B18"), termFg: ("#26332A", "#D4DDD5"), accentBase: ("#3F9B6B", "#6CC495")),
        Theme(id: "rose", name: "Rose",
              ground: ("#FAF4F5", "#1F1B1C"), sidebarBase: ("#F3E8EA", "#262122"),
              termBg: ("#FDF9FA", "#1A1617"), termFg: ("#3A2A2E", "#E3D6D8"), accentBase: ("#D2577A", "#F08AA6")),
        Theme(id: "lavender", name: "Lavender",
              ground: ("#F6F4FB", "#1D1C23"), sidebarBase: ("#EDEAF6", "#24232C"),
              termBg: ("#FBFAFE", "#18171E"), termFg: ("#2E2A44", "#DAD7EA"), accentBase: ("#7A64D8", "#A793F5")),
        Theme(id: "sand", name: "Sand",
              ground: ("#F8F5EF", "#1F1D19"), sidebarBase: ("#EFEADF", "#26231E"),
              termBg: ("#FCFAF6", "#1B1915"), termFg: ("#3A342A", "#E2DDD2"), accentBase: ("#C98A2B", "#E5AE55")),
        Theme(id: "nord", name: "Nord",
              ground: ("#ECEFF4", "#2B303B"), sidebarBase: ("#E3E8F0", "#323845"),
              termBg: ("#F4F6FA", "#2E3440"), termFg: ("#2E3440", "#D8DEE9"), accentBase: ("#5E81AC", "#88C0D0")),
        Theme(id: "mono", name: "Black",
              ground: ("#F4F4F4", "#0E0E0E"), sidebarBase: ("#EAEAEA", "#151515"),
              termBg: ("#FFFFFF", "#0A0A0A"), termFg: ("#111111", "#E5E5E5"), accentBase: ("#6B6B70", "#9A9AA0"))
    ]

    static func named(_ id: String) -> Theme {
        // Themes from earlier versions fall back to the default.
        all.first { $0.id == id } ?? all[0]
    }
}

private struct ThemeKey: EnvironmentKey { static let defaultValue = Theme.all[0] }
extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

/// Spacing/radius tokens (4pt grid).
enum Metrics {
    static let s1: CGFloat = 4, s2: CGFloat = 8, s3: CGFloat = 12, s4: CGFloat = 16, s6: CGFloat = 24
    static let radiusControl: CGFloat = 8, radiusCard: CGFloat = 12
}
