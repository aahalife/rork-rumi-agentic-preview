import SwiftUI

/// Crisp charcoal symbols over diffuse brand light, matching the supplied icon language.
struct BrandGlyph: View {
    let systemName: String
    var tint: Color = Theme.brandMint
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.48, weight: .regular, design: .rounded))
            .foregroundStyle(Theme.ink)
            .frame(width: size, height: size)
            .background {
                Circle().fill(tint.opacity(0.26)).blur(radius: 9).padding(-2)
            }
            .accessibilityHidden(true)
    }
}
