//
//  GlassCard.swift
//  Rumi
//
//  Shared frosted-glass container for every list/card surface:
//  translucent white (#FFFFFF) over a background blur, 1pt solid white
//  border, 24pt continuous corners, and exactly two layered shadows in
//  rgba(0, 32, 25) — the brandPrimaryShade token.
//
//  Shadow note: design-tool "blur" is the full blur extent, while SwiftUI's
//  `radius` matches Core Animation's shadowRadius, which renders at roughly
//  half that. So design blur 10 → radius 5, blur 5 → radius 2.5.
//
//  Blur note: iOS exposes no public API for an arbitrary backdrop-blur radius.
//  `.ultraThinMaterial` is the lightest native material and the closest match
//  to a 12pt background blur.
//

import SwiftUI

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .clipShape(shape) // keeps row press highlights inside the corners
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay(shape.fill(Color.fillPrimary.opacity(0.5)))
                    // Ambient: x 0, y 0, blur 10, spread 0, rgba(0, 32, 25, 0.02)
                    .shadow(color: Color.brandPrimaryShade.opacity(0.02), radius: 5, x: 0, y: 0)
                    // Key: x 0, y 2, blur 5, spread 0, rgba(0, 32, 25, 0.04)
                    .shadow(color: Color.brandPrimaryShade.opacity(0.04), radius: 2.5, x: 0, y: 2)
            }
            .overlay {
                shape.strokeBorder(Color.fillPrimary, lineWidth: 1)
            }
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 24) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

/// Thin row divider, inset to align with the row's text.
struct GlassDivider: View {
    var leadingInset: CGFloat = 54
    var thickness: CGFloat = 0.5

    var body: some View {
        Rectangle()
            .fill(Color.separator)
            .frame(height: thickness)
            .padding(.leading, leadingInset)
    }
}

/// Section header above a glass card, aligned with the card's content.
struct GlassSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.rumiHeadline)
            .foregroundStyle(Color.labelPrimary)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Native-feeling press highlight for tappable rows inside a glass card.
struct GlassRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.fillSecondary.opacity(configuration.isPressed ? 0.7 : 0))
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Trailing disclosure chevron used by rows in glass cards.
struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.rumiFootnote)
            .foregroundStyle(Color.labelQuaternary)
            .accessibilityHidden(true)
    }
}

// MARK: - Static screen background

/// Full-bleed static background image used on every screen that doesn't
/// use the animated AmbientBackground.
struct ScreenBackground: View {
    var body: some View {
        Color.backgroundTertiary
            .overlay {
                Image("ScreenBackground")
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
