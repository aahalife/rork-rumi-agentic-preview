import SwiftUI

/// A short introduction, one optional records door, then home.
struct OnboardingFlowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isConnecting: Bool = false
    @State private var hasAppeared: Bool = false

    var body: some View {
        ZStack {
            BrandAtmosphereView()
            ScrollView {
                VStack(spacing: 32) {
                    VideoOrbView(size: isConnecting ? 92 : 154, state: model.orb, showsHalo: false)
                        .padding(.top, 64)
                        .animation(reduceMotion ? nil : NudgeSpring.gentle, value: isConnecting)
                    if isConnecting {
                        RecordConnectView(onDone: finish)
                            .transition(.opacity)
                    } else {
                        introduction
                            .opacity(hasAppeared ? 1 : 0)
                            .blur(radius: hasAppeared || reduceMotion ? 0 : 5)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            VStack {
                HStack {
                    if isConnecting {
                        Button {
                            withAnimation(reduceMotion ? nil : NudgeSpring.gentle) { isConnecting = false }
                        } label: {
                            Image(systemName: "chevron.left").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Back to introduction")
                    }
                    Spacer()
                    ChromeIcon(systemName: model.musicOn ? "speaker.wave.2.fill" : "speaker.slash", accessibilityText: "Toggle music") { model.musicOn.toggle() }
                }
                .padding(.horizontal, 20)
                Spacer()
            }
        }
        .onAppear {
            SoundEngine.shared.playBed(.onboarding, fade: 3)
            withAnimation(reduceMotion ? nil : .easeOut(duration: 1)) { hasAppeared = true }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Hi, I’m Rumi.")
                .font(NudgeType.serif(38))
                .foregroundStyle(Theme.brandForest)
            Text("A little less to carry.")
                .font(NudgeType.serif(29))
                .foregroundStyle(Theme.ink)
            Text("I help you make sense of your records, prepare for visits, and keep the next step simple. You’re always in charge.")
                .font(NudgeType.rounded(16))
                .foregroundStyle(Theme.inkMuted)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Haptics.glass()
                withAnimation(reduceMotion ? nil : NudgeSpring.gentle) { isConnecting = true }
            } label: {
                Text("Get started")
                    .font(NudgeType.rounded(16, .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color(hex: 0x003B30), in: .capsule)
            }
            .buttonStyle(NudgeButtonStyle())
            .padding(.top, 12)
            Text("Practical support, not a diagnosis or emergency service.")
                .font(NudgeType.rounded(12))
                .foregroundStyle(Theme.inkMuted)
        }
    }

    private func finish() {
        model.epsilonConsent = false
        model.tab = .today
        SoundEngine.shared.playBed(.ambient, fade: 3)
        model.completeOnboarding(values: "", barrier: "", tone: model.tonePreference)
    }
}
