import Foundation
import Observation

/// Consent-gated companion conversation. Live outages remain visible instead
/// of being silently replaced with scripted sample replies.
///
/// The model can act, not just talk: it embeds action tags that become
/// approval cards, trend charts, habit holds, and guide questions.
@Observable final class CompanionEngine {
    var turns: [ConversationTurn] = []
    var isThinking = false

    private let ai = CompanionAI()
    private var streamTask: Task<Void, Never>? = nil
    private var reflectionTask: Task<Void, Never>? = nil
    private var epoch: Int = 0
    private var hasGreeted = false
    private weak var app: AppModel?

    func configure(model: AppModel) {
        app = model
    }

    func reset() {
        epoch += 1
        reflectionTask?.cancel()
        streamTask?.cancel()
        turns = []
        hasGreeted = false
        isThinking = false
    }

    /// Brings back this device's saved conversation for the active profile.
    func restore(_ saved: [SavedTurn]) {
        reset()
        turns = saved.map { ConversationTurn(role: $0.role == "user" ? .user : .companion, text: $0.text) }
        hasGreeted = !turns.isEmpty
    }

    /// Opens a session — greets once, or speaks to a seeded topic.
    func openSession(seed: String?, orb: OrbState) {
        orb.set(.ambient)
        if let seed {
            ask(userVisible: nil, prompt: seedPrompt(for: seed), orb: orb)
        } else if !hasGreeted {
            hasGreeted = true
            ask(userVisible: nil,
                prompt: "Open the conversation with a single short, warm greeting grounded in where I actually am today. No questions about how to help — just be present, then leave space.",
                orb: orb)
        }
    }

    func send(_ text: String, orb: OrbState) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        turns.append(ConversationTurn(role: .user, text: trimmed))
        ask(userVisible: trimmed, prompt: trimmed, orb: orb)
    }

    /// One-tap accept on an inline proposal.
    func resolveRich(turnID: UUID) {
        guard let index = turns.firstIndex(where: { $0.id == turnID }) else { return }
        turns[index].richResolved = true
    }

    func endSession(orb: OrbState) {
        epoch += 1
        streamTask?.cancel()
        reflectionTask?.cancel()
        turns = turns.map { turn in var copy = turn; copy.streaming = false; return copy }
        isThinking = false
        orb.set(.ambient)
    }

    func closeAndReflect(orb: OrbState) {
        endSession(orb: orb)
        reflect()
    }

    private func reflect() {
        guard let app, app.aiPrivacy.processingConsent, app.aiPrivacy.memoryConsent else { return }
        reflectionTask?.cancel()
        let evidence = Array(turns.filter { $0.role == .user }.suffix(10))
        guard !evidence.isEmpty else { return }
        let generation = epoch
        reflectionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let raw = try await ai.stream(system: "Extract only explicitly user-stated preferences, barriers and motivators. Never infer from sample records.", messages: evidence.map { AIChatMessage(role: "user", content: $0.text) }, privacy: app.aiPrivacy, purpose: "reflection") { _ in }
                guard !Task.isCancelled, generation == epoch, app.aiPrivacy.memoryConsent, app.aiPrivacy.processingConsent,
                      let data = raw.data(using: .utf8), let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = object["claims"] as? [[String: Any]] else { return }
                for claim in candidates.prefix(3) {
                    guard let text = claim["text"] as? String, text.count <= 300,
                          let quote = claim["quote"] as? String, quote.count >= 8,
                          let confidence = claim["confidence"] as? Double, confidence.isFinite,
                          let kind = claim["kind"] as? String, ["fact", "hypothesis"].contains(kind),
                          let source = evidence.first(where: { $0.text.contains(quote) }),
                          !app.memory.contains(where: { $0.quote == quote || $0.text.lowercased() == text.lowercased() }) else { continue }
                    app.memory.insert(MemoryItem(text: text, learnedFrom: "Your conversation · awaiting your confirmation", quote: quote, evidenceID: source.id, at: .now, confidence: min(max(confidence, 0), kind == "hypothesis" ? 0.3 : 0.8), claimKind: kind, confirmed: false), at: 0)
                }
                app.persistUserData()
            } catch { /* Reflection never fabricates memory when unavailable. */ }
        }
    }

    /// Voice mode's path — appends the spoken turn, waits for the full reply,
    /// and returns the text to be spoken aloud. Turns land in the same chat
    /// history, so the conversation continues seamlessly in text afterwards.
    func voiceReply(to text: String, orb: OrbState) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        streamTask?.cancel()
        guard let app else { return "Live AI unavailable." }
        epoch += 1
        let generation = epoch
        turns.append(ConversationTurn(role: .user, text: trimmed))
        isThinking = true
        orb.set(.thinking)
        defer { isThinking = false }

        let history = turns.suffix(14).map {
            AIChatMessage(role: $0.role == .user ? "user" : "assistant", content: $0.text)
        }
        let voiceSystem = systemPrompt() + """


        VOICE MODE — you are speaking out loud right now. Keep it to 1–2 short, warm spoken sentences. No lists, no tags except at most one action tag if truly needed, nothing that reads like writing.
        """

        do {
            let raw = try await ai.stream(system: voiceSystem, messages: Array(history), privacy: app.aiPrivacy, purpose: "voice") { _ in }
            try Task.checkCancellation()
            guard generation == epoch, app.aiPrivacy.processingConsent else { return "" }
            let parsed = Self.parse(raw)
            var turn = ConversationTurn(role: .companion, text: parsed.text)
            if parsed.rich != .none { turn.rich = parsed.rich }
            turns.append(turn)
            applySideEffects(parsed)
            app.persistProfileMemory()
            return parsed.text
        } catch {
            guard !Task.isCancelled, generation == epoch else { return "" }
            let reply = "Live AI unavailable · \(error.localizedDescription)"
            turns.append(ConversationTurn(role: .companion, text: reply))
            return reply
        }
    }

    private func seedPrompt(for seed: String) -> String {
        if seed.hasPrefix("symptom:") {
            let kind = String(seed.dropFirst("symptom:".count))
            return "I just logged \(kind) in the quick log. Open the conversation about it — sit with it first, then one useful question or step. If it belongs in front of my care team, draft a guide question with the [[guide:...]] tag."
        }
        return "I tapped into the conversation from: \(seed). Pick this thread up naturally."
    }

    // MARK: - The ask

    private func ask(userVisible: String?, prompt: String, orb: OrbState) {
        epoch += 1
        let generation = epoch
        streamTask?.cancel()
        isThinking = true
        orb.set(.thinking)

        let history = turns.suffix(14).map {
            AIChatMessage(role: $0.role == .user ? "user" : "assistant",
                          text: $0.role == .user ? $0.text : $0.text)
        }
        var messages = Array(history)
        if userVisible == nil {
            messages.append(AIChatMessage(role: "user", text: prompt))
        } else if messages.last?.content != prompt {
            // history already contains the visible user turn
        }
        let system = systemPrompt()
        guard let app else { return }

        let box = StreamBox()
        streamTask = Task { [weak self] in
            guard let self else { return }

            func ensureTurn() {
                if box.turnIndex == nil {
                    isThinking = false
                    orb.set(.speaking)
                    var turn = ConversationTurn(role: .companion, text: "")
                    turn.streaming = true
                    turns.append(turn)
                    box.turnIndex = turns.count - 1
                }
            }

            do {
                _ = try await ai.stream(system: system, messages: messages, privacy: app.aiPrivacy) { [weak self] delta in
                    guard let self, !Task.isCancelled, generation == self.epoch else { return }
                    box.raw += delta
                    // Withhold anything inside [[...]] tags from the visible stream.
                    box.holdback += delta
                    var visible = ""
                    while !box.holdback.isEmpty {
                        if let open = box.holdback.range(of: "[[") {
                            visible += box.holdback[..<open.lowerBound]
                            if let close = box.holdback.range(of: "]]", range: open.upperBound..<box.holdback.endIndex) {
                                box.holdback.removeSubrange(box.holdback.startIndex..<close.upperBound)
                            } else {
                                box.holdback.removeSubrange(box.holdback.startIndex..<open.lowerBound)
                                break
                            }
                        } else if box.holdback.hasSuffix("[") {
                            visible += box.holdback.dropLast()
                            box.holdback = "["
                            break
                        } else {
                            visible += box.holdback
                            box.holdback = ""
                        }
                    }
                    if !visible.isEmpty {
                        if box.turnIndex == nil {
                            self.isThinking = false
                            orb.set(.speaking)
                            var turn = ConversationTurn(role: .companion, text: "")
                            turn.streaming = true
                            self.turns.append(turn)
                            box.turnIndex = self.turns.count - 1
                        }
                        box.shown += visible
                        if let index = box.turnIndex {
                            self.turns[index].text = box.shown.trimmingCharacters(in: .newlines)
                        }
                    }
                }
                guard !Task.isCancelled, generation == epoch else { return }
                ensureTurn()
                if let index = box.turnIndex {
                    let parsed = Self.parse(box.raw)
                    turns[index].text = parsed.text
                    turns[index].streaming = false
                    if parsed.rich != .none {
                        try await Task.sleep(for: .milliseconds(220))
                        guard !Task.isCancelled, turns.indices.contains(index) else { return }
                        turns[index].rich = parsed.rich
                    }
                    applySideEffects(parsed)
                }
            } catch {
                guard !Task.isCancelled, generation == epoch else { return }
                ensureTurn()
                if let index = box.turnIndex, turns.indices.contains(index) {
                    turns[index].text = "Live AI unavailable · \(error.localizedDescription)"
                    turns[index].streaming = false
                }
            }
            guard generation == epoch else { return }
            isThinking = false
            orb.set(.ambient)
            app.persistProfileMemory()
            if turns.filter({ $0.role == .user }).count.isMultiple(of: 5) { reflect() }
        }
    }

    /// Mutable streaming scratchpad shared between the task and the delta
    /// callback — both MainActor, so a plain reference type is safe.
    private final class StreamBox {
        var raw = ""
        var shown = ""
        var holdback = ""
        var turnIndex: Int? = nil
    }

    private func applySideEffects(_ parsed: (text: String, rich: ConversationTurn.Rich)) {
        guard let app else { return }
        if case .guideAdd(let question) = parsed.rich {
            app.addGuideItem(kind: .question, text: question,
                             from: "Drafted in conversation · \(Date.now.formatted(.dateTime.month(.abbreviated).day()))")
        }
    }

    // MARK: - Tag protocol

    /// Strips `[[kind:payload]]` tags and returns the first as a rich element.
    nonisolated static func parse(_ raw: String) -> (text: String, rich: ConversationTurn.Rich) {
        var text = raw
        var rich: ConversationTurn.Rich = .none

        while let open = text.range(of: "[["),
              let close = text.range(of: "]]", range: open.upperBound..<text.endIndex) {
            let inner = String(text[open.upperBound..<close.lowerBound])
            text.removeSubrange(open.lowerBound..<close.upperBound)

            guard rich == .none else { continue }
            let parts = inner.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count >= 1 else { continue }
            let kind = parts[0].lowercased().trimmingCharacters(in: .whitespaces)
            let payload = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            let pieces = payload.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }

            switch kind {
            case "trend":
                rich = .trend(payload.lowercased())
            case "habit":
                rich = .habitProposal(title: pieces.first ?? payload,
                                      context: pieces.count > 1 ? pieces[1] : "whenever today allows")
            case "guide":
                rich = .guideAdd(question: payload)
            case "action", "program": break
            default:
                break
            }
        }
        return (text.trimmingCharacters(in: .whitespacesAndNewlines), rich)
    }

    // MARK: - System prompt (the companion's soul)

    private func systemPrompt() -> String {
        guard let app else { return "You are a warm health companion." }
        let persona = app.persona
        let name = app.displayFirstName

        let conditions = persona.conditions.map { "\($0.name) (\($0.state)) — \($0.plainLine)" }.joined(separator: "\n")
        let meds = app.medications.map { "\($0.name) \($0.dose) — \($0.purposeLine); \($0.scheduleLine)" }.joined(separator: "\n")
        let labs = app.labSeries.map { series in
            let latest = series.latest.map { "\($0.value) \(series.unit) (\($0.date.formatted(.dateTime.month(.abbreviated).day())))" } ?? "—"
            return "\(series.name) [tag id: \(series.id)]: latest \(latest). \(series.explainReading)"
        }.joined(separator: "\n")
        let appointments = app.appointments.map { "\($0.with) — \($0.date.formatted(.dateTime.month().day())) at \($0.location)" }.joined(separator: "\n")
        let plan = persona.carePlan.goals.map { "\($0.title): \($0.detail)\($0.progressLine.map { line in " (status: \(line))" } ?? "")" }.joined(separator: "\n")
        let memories = app.aiPrivacy.memoryConsent ? app.memory.filter { $0.isUsable }.prefix(8).map { "- \($0.text) (\($0.learnedFrom))" }.joined(separator: "\n") : "Memory disabled"
        let recentLogs = app.logs.suffix(5).map { "\($0.kind) severity \(Int($0.severity * 10))/10 on \($0.at.formatted(.dateTime.month(.abbreviated).day()))\($0.note.map { note in " — \(note)" } ?? "")" }.joined(separator: "\n")
        let recentLife = app.entries.prefix(6).map { "\($0.kind.rawValue.dropLast()): \($0.title) (\($0.at.formatted(.dateTime.weekday().hour().minute())))" }.joined(separator: "\n")
        let guide = app.guideItems.filter { !$0.resolved }.map { "- \($0.text)" }.joined(separator: "\n")
        let programLines = app.programs.filter { !$0.declined }.map { program in
            "\(program.title)\(program.enrolled ? " [ENROLLED]" : "")\(program.sponsor.map { sponsor in " [sponsored by \(sponsor) — disclose naturally if you bring it up]" } ?? ""): \(program.summary) Why it fits: \(program.personalFit)"
        }.joined(separator: "\n")
        let pendingActions = app.pendingActions.map { "- \($0.title): \($0.detail)" }.joined(separator: "\n")

        let phaseLine = persona.phase.map { "\($0.kicker) — \($0.headline). \($0.detail)" } ?? ""

        return """
        Consented context for \(name). Active fictional sample patient: \(persona.firstName). User disclosures are separate from sample history.

        VOICE & SOUL
        - Sound like a person. Contractions, rhythm, warmth. Occasionally a short sentence. Never bullet lists unless asked.
        - Default length: 2–4 sentences (~60 words). Depth only when invited.
        - Zero sycophancy. Never open with praise, never say "Great question", never mirror-flatter, never validate just to please. Specific beats nice: "Five readings, one direction" lands harder than "You're doing amazing".
        - Be honest that you are AI, not a nurse. Translate clinical jargon plainly.
        - Hold hard feelings before fixing them. One beat of real acknowledgment, then — only if useful — one small concrete next step. Never two.
        - Tone preference: \(app.tonePreference). Honor it.
        - You may be lightly funny when the moment is light. Never when it's heavy.

        CLINICAL SPINE (hard rules)
        - You never diagnose, never adjust doses, never contradict the care team. You notice, you prepare, you connect.
        - Use only dated instructions for this active sample patient; no generic stop dates or medication safety assurances.
        - When something deserves the care team, route it there warmly — the guide, a drafted note, or a call. Anything that leaves the phone needs \(name)'s explicit approval.
        - Rumi complements \(name)'s patient portal; it does not replace it. Care-team messages, refills, bills, payments and scheduling happen in the portal. When asked, offer to have Rumi Works do it there (with approval), or prepare a draft. Never claim Rumi itself sent, refilled, paid or booked anything.

        BEHAVIORAL INTELLIGENCE (the real job)
        - Every reply quietly serves the goal and plan below. Tie small actions to the person's own why. Make the next step tiny, scheduled, and theirs.
        - Notice patterns across meds, logs, meals, movement and timing — surface them as observations, never accusations.
        - Do not infer sponsored-program eligibility. Emotional support can be the whole response.
        - This release uses a synthetic demo patient. Do not imply sample records are the user’s imported history. External actions are simulations: never claim to have sent, booked, paid, connected or retrieved from a real website. Offer a draft or a labeled demo task instead.
        - Describe patterns as associations, not causes or medical conclusions. Invite correction, and let the user decline or say not now. Do not recommend medication changes from a lifestyle pattern.

        ACTION TAGS — embed at most ONE per reply, at the very end of your message, never inside a sentence:
        [[trend:SERIES_ID]] — show a chart (valid ids are in the labs list below)
        [[habit:Title|when-context]] — propose holding one tiny habit slot
        [[guide:Question text]] — add a drafted question to their visit guide
        Use a tag only when it genuinely helps. Most replies need none.

        WHO \(name.uppercased()) IS
        Pathway: \(persona.switcherLine)
        \(phaseLine)
        Conditions:
        \(conditions)
        Medications:
        \(meds)
        Numbers (chartable):
        \(labs)
        Care plan from \(persona.carePlan.author) (updated \(persona.carePlan.updated)):
        \(plan)
        Upcoming:
        \(appointments)
        Care team office: \(persona.officeName), \(persona.officePhone)
        What you remember about them:
        \(memories)
        Recent symptom logs:
        \(recentLogs.isEmpty ? "none this week" : recentLogs)
        Recent life log (meals, moves, meds):
        \(recentLife)
        Open questions in their visit guide:
        \(guide.isEmpty ? "none yet" : guide)
        Programs available to them:
        \(programLines)
        Steps you've already offered (don't re-offer):
        \(pendingActions.isEmpty ? "none pending" : pendingActions)

        Today is \(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())). Time of day matters — meet them where the day actually is.
        """
    }

}

private extension AIChatMessage {
    init(role: String, text: String) {
        self.init(role: role, content: text)
    }
}
