//
//  AmbientBackground.swift
//  Rumi
//
//  Ambient background: a fixed warm off-white base, three separately blurred
//  glow layers (mint, butter, blush) that float, breathe and pulse on a 12s
//  loop, and a stationary grain overlay.
//
//  Laid out on a 402 × 874 reference. Everything scales uniformly by screen
//  width (ellipses never stretch); the upper glows are anchored to the top edge
//  and the blush to the bottom edge, so the quiet centre absorbs any
//  difference in screen height.
//
//  Performance: each glow is blurred once into a small bitmap when the screen
//  size is known. Per frame we only move, scale and fade those bitmaps, so no
//  blur is recomputed while animating. The timeline pauses when the app is not
//  active, and Reduce Motion shows the static resting composition.
//

import SwiftUI

struct AmbientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var sprites: [GlowSprite] = []

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color.ambientBase

                if reduceMotion {
                    GlowLayers(sprites: sprites, size: size, time: 0)
                } else {
                    TimelineView(.animation(paused: scenePhase != .active)) { context in
                        GlowLayers(
                            sprites: sprites,
                            size: size,
                            time: context.date.timeIntervalSinceReferenceDate
                        )
                    }
                }

                // Stationary grain: drawn once, never animated.
                AmbientGrain()
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .task(id: size.width) {
                guard size.width > 0 else { return }
                sprites = GlowSprite.render(scale: size.width / Horizon.reference.width)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Spec

private struct Glow {
    enum Anchor { case top, bottom }

    /// Top-left corner and size in 402 × 874 reference points.
    let frame: CGRect
    let color: Color
    let opacity: Double
    /// Visual blur value from the design reference.
    let blur: CGFloat
    let anchor: Anchor
    /// Float keyframes: (seconds, offset in reference points).
    let path: [(Double, CGSize)]
    let peak: Double
    let peakScale: CGFloat
    let peakOpacity: Double
}

private enum Horizon {
    static let cycle: Double = 12
    static let reference = CGSize(width: 402, height: 874)
    /// Design blur → Gaussian radius. Calibrated against the reference image.
    static let blurFactor: CGFloat = 0.5

    // Back to front.
    static let glows: [Glow] = [
        // Mint — upper right
        Glow(frame: CGRect(x: 230, y: -170, width: 320, height: 300),
             color: .ambientMint, opacity: 0.65, blur: 120, anchor: .top,
             path: [(0, .zero), (3, CGSize(width: -28, height: 18)), (6, CGSize(width: -72, height: 60)),
                    (9, CGSize(width: -30, height: 78)), (12, .zero)],
             peak: 6, peakScale: 1.20, peakOpacity: 0.95),
        // Butter yellow — right edge
        Glow(frame: CGRect(x: 300, y: 40, width: 200, height: 180),
             color: .ambientButter, opacity: 0.35, blur: 110, anchor: .top,
             path: [(0, .zero), (2, CGSize(width: -20, height: 24)), (4, CGSize(width: -60, height: 72)),
                    (8, CGSize(width: -78, height: 30)), (12, .zero)],
             peak: 4, peakScale: 1.24, peakOpacity: 0.60),
        // Blush — lower left
        Glow(frame: CGRect(x: -160, y: 700, width: 340, height: 260),
             color: .ambientBlush, opacity: 0.35, blur: 130, anchor: .bottom,
             path: [(0, .zero), (4, CGSize(width: 28, height: -24)), (8, CGSize(width: 72, height: -60)),
                    (10, CGSize(width: 36, height: -78)), (12, .zero)],
             peak: 8, peakScale: 1.22, peakOpacity: 0.60),
    ]
}

// MARK: - Easing & keyframes

private enum Ease {
    /// cubic-bezier(0.42, 0, 0.58, 1)
    static func inOut(_ x: Double) -> Double {
        let x1 = 0.42, x2 = 0.58, y1 = 0.0, y2 = 1.0
        func bez(_ t: Double, _ a: Double, _ b: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
        }
        func dBez(_ t: Double, _ a: Double, _ b: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * a + 6 * u * t * (b - a) + 3 * t * t * (1 - b)
        }
        var t = x
        for _ in 0..<6 {
            let d = dBez(t, x1, x2)
            if abs(d) < 1e-6 { break }
            t -= (bez(t, x1, x2) - x) / d
            t = min(max(t, 0), 1)
        }
        return bez(t, y1, y2)
    }

    /// Eased position along keyframes at time `t` within the cycle.
    static func offset(_ path: [(Double, CGSize)], at t: Double) -> CGSize {
        for i in 1..<path.count where t <= path[i].0 {
            let (t0, a) = path[i - 1]
            let (t1, b) = path[i]
            let p = inOut((t - t0) / (t1 - t0))
            return CGSize(width: a.width + (b.width - a.width) * p,
                          height: a.height + (b.height - a.height) * p)
        }
        return path.last?.1 ?? .zero
    }

    /// 0 at start/end of cycle, 1 at `peak`, eased on both legs.
    static func breath(peak: Double, at t: Double, cycle: Double) -> Double {
        t <= peak ? inOut(t / peak) : 1 - inOut((t - peak) / (cycle - peak))
    }
}

// MARK: - Pre-blurred sprites

private struct GlowSprite {
    let image: Image
    /// Sprite size in screen points (ellipse + blur padding).
    let size: CGSize

    /// Renders every glow once, blurred, at low resolution (blurred light has
    /// no fine detail, so 1× upscaled is visually identical and cheap).
    @MainActor
    static func render(scale s: CGFloat) -> [GlowSprite] {
        Horizon.glows.map { glow in
            let radius = glow.blur * Horizon.blurFactor * s
            let pad = radius * 3
            let ellipse = CGSize(width: glow.frame.width * s, height: glow.frame.height * s)
            let canvas = CGSize(width: ellipse.width + pad * 2, height: ellipse.height + pad * 2)

            let content = Ellipse()
                .fill(glow.color)
                .frame(width: ellipse.width, height: ellipse.height)
                .blur(radius: radius)
                .frame(width: canvas.width, height: canvas.height)

            let renderer = ImageRenderer(content: content)
            renderer.scale = 1
            let image = renderer.uiImage.map { Image(uiImage: $0) } ?? Image(systemName: "circle")
            return GlowSprite(image: image, size: canvas)
        }
    }
}

private struct GlowLayers: View {
    let sprites: [GlowSprite]
    let size: CGSize
    let time: Double

    var body: some View {
        let s = size.width / Horizon.reference.width
        let t = time.truncatingRemainder(dividingBy: Horizon.cycle)

        ZStack {
            ForEach(Array(zip(Horizon.glows, sprites).enumerated()), id: \.offset) { _, pair in
                let (glow, sprite) = pair
                let drift = Ease.offset(glow.path, at: t)
                let b = Ease.breath(peak: glow.peak, at: t, cycle: Horizon.cycle)
                let scale = 1 + (glow.peakScale - 1) * b
                let opacity = glow.opacity + (glow.peakOpacity - glow.opacity) * b

                let centerX = glow.frame.midX * s
                let centerY: CGFloat = switch glow.anchor {
                case .top: glow.frame.midY * s
                case .bottom: size.height - (Horizon.reference.height - glow.frame.midY) * s
                }

                sprite.image
                    .resizable()
                    .interpolation(.medium)
                    .frame(width: sprite.size.width, height: sprite.size.height)
                    .scaleEffect(scale, anchor: .center)
                    .opacity(opacity)
                    .position(x: centerX + drift.width * s,
                              y: centerY + drift.height * s)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Grain

private struct AmbientGrain: View {
    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            var rng = SeededGenerator(seed: 0x52554D49) // "RUMI"
            let count = Int(size.width * size.height / 36)
            for _ in 0..<count {
                let x = CGFloat.random(in: 0..<size.width, using: &rng)
                let y = CGFloat.random(in: 0..<size.height, using: &rng)
                let dark = Bool.random(using: &rng)
                context.fill(
                    Path(CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(dark ? Color.labelPrimary.opacity(0.03) : Color.fillPrimary.opacity(0.05))
                )
            }
        }
        .drawingGroup()
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        // SplitMix64
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

#Preview {
    AmbientBackground()
}
