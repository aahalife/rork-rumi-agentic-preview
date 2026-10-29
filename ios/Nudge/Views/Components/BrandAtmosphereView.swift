import SwiftUI

/// Brand light for entry and home only. Media and editorial palettes stay untouched.
struct BrandAtmosphereView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Theme.brandGround
            .overlay {
                TimelineView(.animation(minimumInterval: 1.0 / 15, paused: reduceMotion || scenePhase != .active)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate * 0.025
                    Canvas { context, size in
                        let blooms: [(Double, Double, Color)] = [
                            (0.85 + sin(t) * 0.08, 0.34, Theme.brandMint),
                            (0.12, 0.72 + cos(t) * 0.06, Theme.brandBlush),
                            (0.82, 0.93, Theme.brandSun)
                        ]
                        for (x, y, color) in blooms {
                            let center = CGPoint(x: size.width * x, y: size.height * y)
                            let radius = size.width * 0.9
                            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .radialGradient(Gradient(colors: [color.opacity(scheme == .dark ? 0.16 : 0.22), .clear]), center: center, startRadius: 0, endRadius: radius))
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
