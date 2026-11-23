import SwiftUI

extension Color {
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
}

/// UI + terminal palette. Views read this from the environment; never hardcode colors.
struct Theme: Identifiable, Hashable {
    let id: String
    let name: String
    let accent: Color
    let termBackground: (light: Color, dark: Color)
    let termForeground: (light: Color, dark: Color)

    static func == (l: Theme, r: Theme) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    func background(_ s: ColorScheme) -> Color { s == .dark ? termBackground.dark : termBackground.light }
    func foreground(_ s: ColorScheme) -> Color { s == .dark ? termForeground.dark : termForeground.light }

    static let all: [Theme] = [
        Theme(id: "default", name: "Default", accent: .accentColor,
              termBackground: (Color(hex: "#FFFFFF"), Color(hex: "#1C1C1E")),
              termForeground: (Color(hex: "#1C1C1E"), Color(hex: "#EDEDED"))),
        Theme(id: "ocean", name: "Ocean", accent: Color(hex: "#0A84FF"),
              termBackground: (Color(hex: "#F3F8FF"), Color(hex: "#0D1B2A")),
              termForeground: (Color(hex: "#10243A"), Color(hex: "#D6E4F0"))),
        Theme(id: "forest", name: "Forest", accent: Color(hex: "#30B26B"),
              termBackground: (Color(hex: "#F4FAF6"), Color(hex: "#102019")),
              termForeground: (Color(hex: "#14291F"), Color(hex: "#D5EBDD"))),
        Theme(id: "sunset", name: "Sunset", accent: Color(hex: "#FF7A45"),
              termBackground: (Color(hex: "#FFF8F3"), Color(hex: "#241612")),
              termForeground: (Color(hex: "#3A2218"), Color(hex: "#F3DDD2"))),
        Theme(id: "grape", name: "Grape", accent: Color(hex: "#8E6CF0"),
              termBackground: (Color(hex: "#F7F4FF"), Color(hex: "#1A1426")),
              termForeground: (Color(hex: "#2A2046"), Color(hex: "#E3DBF7"))),
        Theme(id: "mono", name: "Mono", accent: Color(hex: "#8E8E93"),
              termBackground: (Color(hex: "#F5F5F5"), Color(hex: "#111111")),
              termForeground: (Color(hex: "#111111"), Color(hex: "#E5E5E5")))
    ]

    static func named(_ id: String) -> Theme { all.first { $0.id == id } ?? all[0] }
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
