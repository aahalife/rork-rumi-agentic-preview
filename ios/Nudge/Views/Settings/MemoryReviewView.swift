import SwiftUI

struct MemoryReviewView: View {
    @Environment(AppModel.self) private var model
    let memory: MemoryItem
    @State private var correction: String = ""
    @State private var isEditing: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(memory.text).font(NudgeType.rounded(14))
            Text(memory.learnedFrom).font(NudgeType.rounded(12)).foregroundStyle(Theme.inkMuted)
            if let at = memory.at { Text(at, style: .date).font(NudgeType.rounded(12)) }
            if let quote = memory.quote { Text("“\(quote)”").font(NudgeType.rounded(12)).foregroundStyle(Theme.inkMuted) }
            if let confidence = memory.confidence { Text("\(Int(confidence * 100))% confidence · \(memory.claimKind ?? "fact")").font(NudgeType.rounded(12)) }
            if isEditing {
                TextField("Corrected memory", text: $correction, axis: .vertical)
                Button("Save correction") { update(correction, corrected: true); isEditing = false }
                    .frame(minHeight: 44)
            }
            HStack {
                if memory.confirmed == false { Button("That’s right") { update(memory.text, corrected: false) } }
                Button("Correct") { correction = memory.text; isEditing = true }
                Button("Forget", role: .destructive) { model.deleteMemory(memory.id) }
            }.frame(minHeight: 44)
        }
        .padding(14).background(.thinMaterial, in: .rect(cornerRadius: 18))
    }

    private func update(_ text: String, corrected: Bool) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let index = model.memory.firstIndex(where: { $0.id == memory.id }) else { return }
        model.companion.reset()
        model.memory[index].text = String(text.prefix(300))
        model.memory[index].confirmed = true
        model.memory[index].claimKind = "fact"
        model.memory[index].confidence = 1
        model.memory[index].at = .now
        model.memory[index].learnedFrom = corrected ? "Corrected by you" : "Confirmed by you"
        if corrected { model.memory[index].quote = String(text.prefix(300)) }
        model.persistUserData()
    }
}
