import SwiftUI

/// Readable frosted content with a luminous double rim; Liquid Glass stays on controls.
struct FrostedSurface: ViewModifier {
    var radius: CGFloat = 30
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background {
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                if reduceTransparency {
                    shape.fill(Theme.surface)
                } else {
                    shape.fill(.regularMaterial)
                        .overlay { shape.fill(Theme.surface.opacity(scheme == .dark ? 0.36 : 0.38)) }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.linearGradient(colors: [.white.opacity(scheme == .dark ? 0.32 : 0.98), .white.opacity(0.20), .white.opacity(scheme == .dark ? 0.18 : 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: max(0, radius - 4), style: .continuous)
                    .strokeBorder(Color.white.opacity(scheme == .dark ? 0.06 : 0.38), lineWidth: 0.7)
                    .padding(4).allowsHitTesting(false)
            }
            .shadow(color: Theme.shadow.opacity(0.10), radius: 22, y: 8)
    }
}

extension View {
    /// Shared frosted card treatment matching the Rumi brand reference.
    func frostedSurface(radius: CGFloat = 30) -> some View {
        modifier(FrostedSurface(radius: radius))
    }
}
