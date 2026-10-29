import SwiftUI

/// The floating liquid-glass dock — three destinations. A single capsule of
/// true Liquid Glass on iOS 26; the selected tab is marked only by a quiet
/// tinted highlight behind its icon — no big sliding pill.
/// Rumi AI stays accessible at the center, regardless of page scroll position.
struct NudgeDock: View {
    @Environment(AppModel.self) private var model
    @State private var tapped = false

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                // A soft cool/bright tint lifts the glass off the warm living
                // ground so the refraction and edge actually read — untinted
                // glass over the warm gradient nearly vanished.
                bar
                    .background(Theme.surface.opacity(0.86), in: .capsule)
                    .glassEffect(.regular.tint(Theme.dockTint), in: .capsule)
                    .overlay(
                        Capsule().strokeBorder(
                            .linearGradient(
                                colors: [Color.white.opacity(0.55), Color.white.opacity(0.08)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 0.9
                        )
                    )
            } else {
                bar
                    .background(Theme.surface.opacity(0.86), in: .capsule)
                    .background(.regularMaterial, in: .capsule)
                    .overlay(Capsule().strokeBorder(Theme.edge.opacity(0.5), lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .shadow(color: Theme.shadow.opacity(0.22), radius: 24, y: 11)
        .sensoryFeedback(.impact(weight: .light), trigger: tapped)
    }

    private var bar: some View {
        HStack(spacing: 0) {
            dockItem(.today)
            dockItem(.care)
            Button { model.openConversation() } label: {
                VStack(spacing: 1) {
                    OrbView(size: 40, state: model.orb)
                    Text("Rumi AI").font(NudgeType.rounded(10, .semibold))
                }
                .foregroundStyle(Theme.brandForest)
                .frame(maxWidth: .infinity).frame(minHeight: 56)
            }
            .buttonStyle(NudgeButtonStyle())
            .accessibilityLabel("Talk with Rumi AI")
            dockItem(.you)
            Button { model.showAgentNetwork = true } label: {
                VStack(spacing: 3) {
                    Image(systemName: needsApproval ? "hand.raised" : "sparkles").font(.system(size: 20))
                    Text(needsApproval ? "Review" : "Work").font(NudgeType.rounded(12, .medium))
                }
                .foregroundStyle(needsApproval ? Theme.brandForest : Theme.inkMuted)
                .frame(maxWidth: .infinity).frame(minHeight: 56)
            }
            .buttonStyle(NudgeButtonStyle())
            .accessibilityLabel(needsApproval ? "Review pending approval" : "Open task workspace")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }

    private var needsApproval: Bool {
        model.browserDemo.phase == .review || model.portalCompanion.session?.pendingConfirm != nil
    }

    private func dockItem(_ tab: AppModel.Tab) -> some View {
        let selected = model.tab == tab || (tab == .you && (model.tab == .journeys || model.tab == .currents))
        let badge = tab == .care ? model.careUnreadCount : 0
        return Button {
            tapped.toggle()
            withAnimation(NudgeSpring.ui) { model.tab = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.glyph)
                    .font(.system(size: 21, weight: .regular, design: .rounded))
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 {
                            Circle()
                                .fill(Theme.warm)
                                .frame(width: 7, height: 7)
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 1))
                                .offset(x: 6, y: -3)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                Text(tab.rawValue)
                    .font(NudgeType.rounded(12, .medium))
            }
            .foregroundStyle(selected ? Theme.ink : Theme.inkMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
                if selected {
                    Capsule(style: .continuous)
                        .fill(Theme.brandMint.opacity(0.20))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                }
            }
            .animation(NudgeSpring.ui, value: selected)
            .contentShape(Rectangle())
        }
        .buttonStyle(NudgeButtonStyle())
        .accessibilityLabel(badge > 0 ? "\(tab.rawValue), \(badge) new" : tab.rawValue)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
