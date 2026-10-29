import SwiftUI

struct AIPrivacySettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var privacy = model.aiPrivacy
        VStack(alignment: .leading, spacing: 12) {
            Text("Rumi AI").font(NudgeType.serif(22))
            Text("Rumi AI is on. It processes relevant fictional patient context and your chat/logs securely through our backend and an external AI service. Voice, when you open the microphone, also uses ElevenLabs for transcription and playback. This is not medical care, and the app still works with AI off.")
                .font(NudgeType.rounded(13)).foregroundStyle(Theme.inkMuted)
            Toggle("Rumi AI", isOn: $privacy.processingConsent)
            Toggle("Remember our conversations", isOn: $privacy.memoryConsent)
            Text("Memory stays on this iPhone, separately for each sample profile. Other people using the same demo profile never see it. AI memory suggestions wait for your confirmation, and dated claims retire after 45 days.")
                .font(NudgeType.rounded(12)).foregroundStyle(Theme.inkMuted)
            ForEach(model.memory) { memory in MemoryReviewView(memory: memory) }
            Text("Fair-use limits apply per device so everyone gets a turn.")
                .font(NudgeType.rounded(12)).foregroundStyle(Theme.inkMuted)
        }
        .tint(Theme.life)
        .onChange(of: privacy.processingConsent) { _, _ in model.companion.endSession(orb: model.orb); model.liveSupport.cancel() }
        .onChange(of: privacy.memoryConsent) { _, _ in model.companion.reset(); model.liveSupport.cancel(); model.persistProfileMemory() }
    }
}
