import Foundation
import Observation

/// In-app support only; no push delivery, hidden profiling or closed-app monitoring.
@Observable final class LiveSupportService {
    var items: [LiveSupportItem] = []
    var status: String = "Live support is optional."
    private var task: Task<Void, Never>? = nil
    private var generation: Int = 0
    private var patient: String = ""
    private var events: [Double] = []
    private var dismissed: [String] = []
    private var lastDismissal: Double = 0

    func configure(patient: String) {
        cancel(); self.patient = patient
        let key = "rumi.support.\(patient)"
        if let data = UserDefaults.standard.data(forKey: key), let saved = try? JSONDecoder().decode([LiveSupportItem].self, from: data) { items = saved } else { items = [] }
        events = UserDefaults.standard.array(forKey: key + ".events") as? [Double] ?? []
        dismissed = UserDefaults.standard.stringArray(forKey: key + ".dismissed") ?? []
        lastDismissal = UserDefaults.standard.double(forKey: key + ".lastDismissal")
    }

    func cancel() { generation += 1; task?.cancel(); task = nil }

    func clear() {
        cancel(); items = []; events = []; dismissed = []; lastDismissal = 0; persist()
    }

    func dismiss(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        cancel(); dismissed.append(item.title); lastDismissal = Date.now.timeIntervalSince1970
        items.removeAll { $0.id == id }; persist()
    }

    func refresh(kind: String, model: AppModel) {
        guard task == nil else { return }
        guard model.aiPrivacy.processingConsent else { status = "Rumi AI is turned off in Settings."; return }
        let hour = Calendar.current.component(.hour, from: .now)
        let quiet = model.quietStart == model.quietEnd || (model.quietStart < model.quietEnd ? hour >= model.quietStart && hour < model.quietEnd : hour >= model.quietStart || hour < model.quietEnd)
        guard !quiet, model.notificationClasses[kind == "nudge" ? "Habit moments" : "Insights"] != false else { status = "Resting during quiet hours or your category opt-out."; return }
        let recent = model.companion.turns.filter { $0.role == .user }.suffix(3).map(\.text).joined(separator: " ").lowercased()
        guard !["suicid", "kill myself", "end my life", "hopeless", "scared", "overwhelmed", "devastated", "bad news", "chest pain", "can't breathe", "died"].contains(where: recent.contains) else { status = "No coaching agenda right now. Conversation is here if you want it."; return }
        let now = Date.now.timeIntervalSince1970
        guard events.filter({ now - $0 < 86400 }).count < 2, events.filter({ now - $0 < 7 * 86400 }).count < 8, now - lastDismissal > 86400 else { status = "Giving you space. Two live checks/day, eight/week, and a day off after dismissal."; return }
        let evidence: [LiveSupportItem.Evidence] = model.logs.suffix(5).map { log in .init(id: log.id.uuidString, text: "User symptom log: \(log.kind), \(log.at.formatted()), \(log.note ?? "")") } + model.entries.prefix(5).map { entry in .init(id: entry.id.uuidString, text: "Local sample-app entry (may be fictional): \(entry.title), \(entry.at.formatted())") }
        guard !evidence.isEmpty else { status = "Not enough dated evidence yet."; return }
        let context = "Fictional sample patient \(model.persona.firstName). Goals: \(model.persona.carePlan.goals.map(\.title).joined(separator: "; ")). Evidence: \(evidence.map { "ID \($0.id): \($0.text)" }.joined(separator: "\n")). Previously dismissed: \(dismissed.joined(separator: "; ")). No planned behavior is a completion log."
        generation += 1
        let epoch = generation
        events.append(now); persist(); status = "Considering the context…"
        task = Task { [weak self, weak model] in
            guard let self, let model else { return }
            defer { if epoch == generation { task = nil } }
            do {
                let raw = try await CompanionAI().stream(system: context, messages: [AIChatMessage(role: "user", content: "Offer one optional \(kind) only if supported; otherwise skip.")], privacy: model.aiPrivacy, purpose: kind) { _ in }
                guard !Task.isCancelled, generation == epoch, model.aiPrivacy.processingConsent,
                      let data = raw.data(using: .utf8), let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                guard result["skip"] as? Bool != true, let title = result["title"] as? String, title.count <= 120,
                      let body = result["body"] as? String, body.count <= 900, let ids = result["evidenceIds"] as? [String], !ids.isEmpty,
                      ids.allSatisfy({ id in evidence.contains(where: { $0.id == id }) }) else { status = "Nothing useful to add right now."; return }
                items = Array(([LiveSupportItem(id: UUID(), title: title, body: body, evidence: evidence.filter { ids.contains($0.id) }, kind: kind, at: .now)] + items.filter { $0.title != title && Date.now.timeIntervalSince($0.at) < 86400 }).prefix(3))
                persist(); status = "A live AI observation · not a clinical conclusion."
            } catch { if !Task.isCancelled, epoch == generation { status = "Live support unavailable. Please try later; no sample content substituted." } }
        }
    }

    private func persist() {
        let key = "rumi.support.\(patient)"
        if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: key) }
        UserDefaults.standard.set(Array(events.suffix(20)), forKey: key + ".events")
        UserDefaults.standard.set(Array(dismissed.suffix(20)), forKey: key + ".dismissed")
        UserDefaults.standard.set(lastDismissal, forKey: key + ".lastDismissal")
    }
}
