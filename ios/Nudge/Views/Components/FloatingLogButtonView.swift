import SwiftUI

/// Root-owned logging shortcut; never inherits a page's scrolling or transforms.
struct FloatingLogButtonView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            Haptics.pull()
            SoundEngine.shared.glass()
            model.quickLogMedID = nil
            model.showQuickLog = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(Theme.ink)
                .frame(width: 56, height: 56)
                .background(Theme.surface.opacity(0.92), in: .circle)
                .background(.regularMaterial, in: .circle)
                .overlay(Circle().strokeBorder(Theme.brandMint.opacity(0.6), lineWidth: 1.5))
                .shadow(color: Theme.shadow.opacity(0.2), radius: 14, y: 6)
        }
        .buttonStyle(NudgeButtonStyle())
        .accessibilityLabel("Log something — a symptom, a meal, a move, a med")
        .padding(.trailing, 22)
        .padding(.bottom, 96)
    }
}
