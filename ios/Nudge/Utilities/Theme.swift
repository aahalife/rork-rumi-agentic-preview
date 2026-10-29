import SwiftUI

extension Color {
    /// Creates a color from a 0xRRGGBB hex value.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }

    /// Creates a dynamic color that resolves per appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }
}

/// Semantic design tokens — two worlds, one soul.
/// Light: "Clay & Dawn". Dark: "Indigo Night". Never hardcode colors in views.
/// Earthy means the *feel* — the palette itself stays luminous and alive.
enum Theme {
    // Branding is deliberately separate from illustration and editorial tokens.
    static let brandMint = Color(hex: 0x4BC5AB)
    static let brandBlush = Color(hex: 0xF2BDB5)
    static let brandSun = Color(hex: 0xFFE580)
    static let brandForest = Color(light: 0x003B30, dark: 0xA0E4D1)
    static let brandGround = Color(light: 0xF8FAF8, dark: 0x10241F)

    // MARK: Ground
    static let base = Color(light: 0xF8FAF8, dark: 0x10241F)
    /// Surfaces sit clearly above the ground — porcelain-bright in daylight,
    /// raised indigo at night. Never the same value as the base.
    static let surface = Color(light: 0xFFFFFF, dark: 0x1A332B)
    static let raised = Color(light: 0xEFF7F1, dark: 0x244338)
    static let ink = Color(light: 0x343937, dark: 0xF0F7F1)
    /// Secondary text still has to *read* over the bright living gradient —
    /// deeper than a classic placeholder grey.
    static let inkMuted = Color(light: 0x646C68, dark: 0xAECABD)

    /// Hairline borders that separate surfaces from the living ground.
    static let edge = Color(light: 0xDCE8DF, dark: 0x3C5C4F)
    /// Tinted shadow under surfaces — warm clay by day, deep indigo by night.
    static let shadow = Color(light: 0x89A995, dark: 0x000000)

    /// A cool/bright tint laid under the floating dock's Liquid Glass so its
    /// refraction and edge read against the warm living ground (untinted glass
    /// nearly disappeared over the gradient).
    static let dockTint = Color(light: 0xF4FFF8, dark: 0x315A48).opacity(0.30)

    // MARK: Accents (light → dark pairings) — vivid, never muddy
    static let warm = Color(light: 0xE0764E, dark: 0xFF9E7E)      // terracotta → coral glow
    static let life = Color(light: 0x7FAE7E, dark: 0x8FEFC0)      // sage → mint
    static let sky = Color(light: 0x6E9CC8, dark: 0x8FC6FF)       // dusty sky → sky
    static let gold = Color(light: 0xD9A348, dark: 0xC8B6FF)      // sand gold → lavender
    static let rose = Color(light: 0xD8849B, dark: 0xFF9FB2)      // dusty rose → rose glow

    /// Attention is carried by warm luminance — never red, never alarms.
    static let attention = Color(light: 0xD98A3D, dark: 0xFFBE8F)

    /// Companion gradient shells.
    static func companion(_ scheme: ColorScheme) -> [Color] {
        scheme == .dark
            ? [Color(hex: 0x6EE7D8), Color(hex: 0x9D8CFF), Color(hex: 0xFF9FB2)]
            : [Color(hex: 0xFFC9A8), Color(hex: 0xF2A0BC), Color(hex: 0xB39DE8)]
    }

    /// Soft pastel halo behind the orb — the orb never floats on bare ground.
    static func orbHalo(_ scheme: ColorScheme) -> [Color] {
        scheme == .dark
            ? [Color(hex: 0x4BC5AB).opacity(0.25), Color(hex: 0xFFE580).opacity(0.12), .clear]
            : [Color(hex: 0x4BC5AB).opacity(0.25), Color(hex: 0xFFE580).opacity(0.18), .clear]
    }

    /// Living-gradient palette tuned per time of day — visibly alive,
    /// dawn-rose to dusk-amber to night-indigo.
    static func gradientPalette(scheme: ColorScheme, hour: Int) -> (Color, Color, Color) {
        if scheme == .dark {
            // Night is indigo with real color in it — violet, teal and dusk-rose
            // blooms so the ground never reads as one flat navy.
            switch hour {
            case 5..<9: return (Color(hex: 0x183D32), Color(hex: 0x234538), Color(hex: 0x10241F))
            case 9..<17: return (Color(hex: 0x163C32), Color(hex: 0x244A3D), Color(hex: 0x10241F))
            case 17..<21: return (Color(hex: 0x244333), Color(hex: 0x17382E), Color(hex: 0x10241F))
            default: return (Color(hex: 0x17372D), Color(hex: 0x214137), Color(hex: 0x10241F))
            }
        } else {
            switch hour {
            case 5..<9: return (Color(hex: 0xE3F5EA), Color(hex: 0xFFF4CD), Color(hex: 0xF8FAF8))
            case 9..<17: return (Color(hex: 0xDDF4EA), Color(hex: 0xF3F8EF), Color(hex: 0xF8FAF8))
            case 17..<21: return (Color(hex: 0xE6F3E8), Color(hex: 0xFFF3CF), Color(hex: 0xF8FAF8))
            default: return (Color(hex: 0xE5F2EA), Color(hex: 0xF1F5E8), Color(hex: 0xF8FAF8))
            }
        }
    }

    /// Deeper, more atmospheric palette for the immersive conversation scene.
    static func conversationPalette(_ scheme: ColorScheme) -> (Color, Color, Color) {
        scheme == .dark
            ? (Color(hex: 0x183C32), Color(hex: 0x23483B), Color(hex: 0x10241F))
            : (Color(hex: 0xDDF4EA), Color(hex: 0xFFF4CD), Color(hex: 0xF8FAF8))
    }
}
