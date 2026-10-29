import SwiftUI

struct PlannedActivityView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let planned = model.activityPlannedAt {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image("wellness_routine_figures").resizable().scaledToFill()
                        .frame(width: 76, height: 76).clipped().clipShape(.rect(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Gentle mobility & a short walk").font(NudgeType.serif(19))
                        Text("15 minutes · planned \(planned.formatted(date: .abbreviated, time: .omitted))")
                            .font(NudgeType.rounded(12)).foregroundStyle(Theme.inkMuted)
                    }
                }
                Text("@move.kindly · fictional saved post. Five minutes of comfortable standing mobility and ten minutes of easy walking. Follow care-team limits; stop if uncomfortable. Prepared clay artwork.")
                    .font(NudgeType.rounded(13)).foregroundStyle(Theme.inkMuted)
                Button("I did this · log activity") {
                    model.addEntry(kind: .move, text: "Gentle mobility & a short walk", note: "Completed by you; fictional movement post, not a clinical prescription.")
                    model.activityPlannedAt = nil
                    model.persistUserData()
                }.frame(minHeight: 44)
                Button("Remove plan") { model.activityPlannedAt = nil; model.persistUserData() }
                    .frame(minHeight: 44)
            }.padding(16).frostedSurface(radius: 24)
        }
    }
}
