import SwiftUI

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")))
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    // Brand
    static let brandPrimary = Color(hex: "#006B58")
    static let brandPrimaryShade = Color(hex: "#002019")
    static let brandPrimaryTint = Color(hex: "#7FF7D8")
    static let brandSecondary = Color(hex: "#4B635C")
    static let brandSecondaryShade = Color(hex: "#07201A")
    static let brandSecondaryTint = Color(hex: "#CDE9DE")
    static let brandTertiary = Color(hex: "#426277")
    static let brandTertiaryShade = Color(hex: "#001E2D")
    static let brandTertiaryTint = Color(hex: "#C6E7FF")

    // Backgrounds
    static let backgroundPrimary = Color(hex: "#F2FCF6")
    static let backgroundSecondary = Color(hex: "#E6F0EB")
    static let backgroundTertiary = Color(hex: "#FFFFFF")

    // Fills
    static let fillPrimary = Color(hex: "#FFFFFF")
    static let fillPrimaryContrast = Color(hex: "#141D1A")
    static let fillSecondary = Color(hex: "#E0EAE5")
    static let fillTertiary = Color(hex: "#ECF6F1")
    static let fillQuaternary = Color(hex: "#F2FCF6")

    // Labels (text)
    static let labelPrimary = Color(hex: "#141D1A")
    static let labelPrimaryContrast = Color(hex: "#FFFFFF")
    static let labelSecondary = Color(hex: "#3F4945")
    static let labelTertiary = Color(hex: "#57605D")
    static let labelQuaternary = Color(hex: "#89938F")

    // Separator
    static let separator = Color(hex: "#BFC9C4")

    // Inline alerts
    static let alertWarningFill = Color(hex: "#FFDDB0")
    static let alertErrorFill = Color(hex: "#FFDAD5")
    static let alertErrorLabel = Color(hex: "#B4271F")

    // Ambient background — full-strength; opacity applied per layer
    static let ambientBase = Color(hex: "#F6F6F2")
    static let ambientMint = Color(hex: "#A8E8D5")
    static let ambientButter = Color(hex: "#FFE9A6")
    static let ambientBlush = Color(hex: "#F6CFC8")
}

// Type ramp: native iOS text styles only (SF Pro, Dynamic Type).
extension Font {
    static let rumiLargeTitle = Font.largeTitle     // 34
    static let rumiTitle1 = Font.title              // 28
    static let rumiTitle2 = Font.title2             // 22
    static let rumiTitle3 = Font.title3             // 20
    static let rumiHeadline = Font.headline         // 17 semibold
    static let rumiBody = Font.body                 // 17
    static let rumiCallout = Font.callout           // 16
    static let rumiSubheadline = Font.subheadline   // 15
    static let rumiFootnote = Font.footnote         // 13
    static let rumiCaption1 = Font.caption          // 12
    static let rumiCaption2 = Font.caption2         // 11
}
