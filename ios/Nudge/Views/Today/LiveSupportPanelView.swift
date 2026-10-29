import SwiftUI

struct LiveSupportPanelView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.aiPrivacy.processingConsent {
            VStack(alignment: .leading, spacing: 12) {
                Text("Live support · when useful").font(NudgeType.serif(22))
                Text(model.liveSupport.status).font(NudgeType.rounded(12)).foregroundStyle(Theme.inkMuted)
                HStack {
                    Button("One gentle next step") { model.liveSupport.refresh(kind: "nudge", model: model) }
                    Button("Reflect on my logs") { model.liveSupport.refresh(kind: "insight", model: model) }
                }.font(NudgeType.rounded(13)).frame(minHeight: 44)
                ForEach(model.liveSupport.items.filter { Date.now.timeIntervalSince($0.at) < 86400 }.prefix(3)) { item in
                    DisclosureGroup(item.title) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(item.body).font(NudgeType.rounded(14))
                            Text("Rumi AI · \(item.at.formatted()) · AI observation, not medical advice")
                                .font(NudgeType.rounded(12)).foregroundStyle(Theme.inkMuted)
                            DisclosureGroup("Why this?") {
                                ForEach(item.evidence, id: \.id) { source in Text(source.text).font(NudgeType.rounded(12)) }
                            }
                            Button("Talk about this") { model.openConversation(seed: "Live \(item.kind): \(item.title). \(item.body). Evidence: \(item.evidence.map(\.text).joined(separator: "; "))") }.frame(minHeight: 44)
                            Button("Not now · rest for a day") { model.liveSupport.dismiss(item.id) }.frame(minHeight: 44)
                        }.padding(.top, 8)
                    }.font(NudgeType.rounded(15)).padding(14).frostedSurface(radius: 22)
                }
            }.foregroundStyle(Theme.ink).tint(Theme.life)
        }
    }
}
