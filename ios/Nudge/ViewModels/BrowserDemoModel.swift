import Foundation
import Observation

/// An isolated, offline demonstration. This model never opens a website or mutates provider records.
@Observable final class BrowserDemoModel {
    enum Scenario: String, CaseIterable, Identifiable {
        case labs, visit, recipe, ride, activity
        var id: String { rawValue }
        var title: String {
            switch self {
            case .labs: return "Check my latest labs"
            case .visit: return "Prepare for my visit"
            case .recipe: return "Find a saved recipe"
            case .ride: return "Arrange a ride"
            case .activity: return "Find gentle movement"
            }
        }
        var page: String {
            switch self {
            case .labs: return "MyChart-style portal / Test results"
            case .visit: return "MyChart-style portal / Messages"
            case .recipe: return "Recipe library / Saved recipes"
            case .ride: return "Ride service / Review trip"
            case .activity: return "Movement library / Saved post"
            }
        }
        var steps: [String] {
            switch self {
            case .labs: return ["Opening your test results", "Comparing the result with your history", "Preparing a question for your visit"]
            case .visit: return ["Opening your visit details", "Gathering your questions and observations", "Preparing a message for your care team"]
            case .recipe: return ["Opening your saved collection", "Finding a simple chickpea and herb bowl", "Preparing a recipe to save locally"]
            case .ride: return ["Opening the ride page", "Checking the appointment destination", "Preparing a trip for your review"]
            case .activity: return ["Opening your saved movement post", "Reading the mobility and short walk routine", "Saving a local plan, not a completion log"]
            }
        }
    }
    enum Phase: String { case idle, login, browsing, paused, review, done, stopped, failed }
    private(set) var scenario: Scenario? = nil
    private(set) var phase: Phase = .idle
    private(set) var step: Int = 0
    private(set) var reviewText: String = ""
    private(set) var patientName: String = ""
    private(set) var receipt: String? = nil
    var isCollapsed: Bool = false
    private(set) var fare: Int = 24
    var onLocalCompletion: ((Scenario) -> Void)? = nil
    private var runner: Task<Void, Never>? = nil
    private var run: Int = 0

    private func schedule() {
        runner?.cancel(); run += 1
        let generation = run
        runner = Task { [weak self] in
            while !Task.isCancelled {
                let isLogin = self?.phase == .login
                do { try await Task.sleep(for: isLogin ? .milliseconds(1800) : .milliseconds(2400)) } catch { return }
                guard let self, self.run == generation, !Task.isCancelled else { return }
                if self.phase == .login { self.continueDemoLogin() }
                else if self.phase == .browsing { self.advance() }
                else { return }
            }
        }
    }

    private func cancelRunner() { run += 1; runner?.cancel(); runner = nil }
    struct Message: Identifiable {
        let id: UUID = UUID()
        let isUser: Bool
        let text: String
    }
    private(set) var messages: [Message] = []

    /// Guided follow-ups never grant approval or accept login credentials.
    func followUp(_ input: String) {
        let text = String(input.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000))
        guard !text.isEmpty, scenario != nil, phase != .login else { return }
        let command = text.lowercased()
        let reply: String
        switch command {
        case "stop", "cancel", "decline": stop(); reply = activity
        case "pause": pause(); reply = activity
        case "resume": resume(); reply = activity
        case "continue", "next", "show next step": advance(); reply = activity
        default:
            if ["send", "book", "approve", "pay", "save"].contains(where: command.contains) {
                reply = "Use the approval card to review the exact proposal. Chat never authorizes a submission."
            } else if ["explain", "what", "which", "where", "summary", "detail"].contains(where: command.contains) {
                reply = "From this sample task: \(reviewText)"
            } else {
                reply = "This guided workspace supports Explain this, Continue, Pause, Resume and Stop. Open-ended live browsing is not connected here."
            }
        }
        messages.append(Message(isUser: true, text: text))
        messages.append(Message(isUser: false, text: reply))
        messages = Array(messages.suffix(30))
    }

    var statusLabel: String {
        switch phase {
        case .idle: return "How can I help?"
        case .login: return "Your turn"
        case .browsing: return "In progress"
        case .paused: return "Paused"
        case .review: return "Needs your okay"
        case .done: return "Finished"
        case .stopped: return "Stopped"
        case .failed: return "Interrupted"
        }
    }
    var activity: String {
        switch phase {
        case .idle: return "Choose something you would like Rumi to help with."
        case .login: return "Opening the fixed sample profile automatically. No credentials required."
        case .browsing: return scenario?.steps[step] ?? "Preparing your task"
        case .paused: return "Nothing advances while paused. Resume when you’re ready."
        case .review: return "Ready for your review. Nothing happens until you approve."
        case .done: return "Your task summary is ready to review."
        case .stopped: return "Stopped. Nothing was sent, booked, charged or saved by this task."
        case .failed: return "The session was interrupted. No action was taken."
        }
    }
    var canStop: Bool { [.login, .browsing, .paused, .review, .failed].contains(phase) }

    func start(_ selection: Scenario, patient: String, detail: String) {
        guard !canStop else { return }
        scenario = selection
        patientName = patient
        reviewText = detail
        phase = .login
        step = 0
        fare = 24
        receipt = nil
        messages = []
        isCollapsed = false
        schedule()
    }
    func continueDemoLogin() { guard phase == .login else { return }; phase = .browsing }
    func advance() {
        guard phase == .browsing, let scenario else { return }
        if step < scenario.steps.count - 1 { step += 1 }
        else if scenario == .visit || scenario == .ride { phase = .review }
        else {
            phase = .done
            receipt = "Task summary · \(scenario.title)\n\(reviewText)\nPrepared locally; no external action taken. Plans are not completion logs."
            onLocalCompletion?(scenario)
        }
    }
    func pause() { guard phase == .browsing else { return }; cancelRunner(); phase = .paused }
    func resume() { guard phase == .paused else { return }; phase = .browsing; schedule() }
    func interrupt() { guard phase == .browsing else { return }; cancelRunner(); phase = .failed }
    func retry() { guard phase == .failed else { return }; phase = .login; step = 0; schedule() }
    func stop() { guard canStop else { return }; cancelRunner(); phase = .stopped; receipt = nil }
    func approve() {
        guard phase == .review, let scenario else { return }
        phase = .done
        receipt = "Task summary · \(scenario.title)\n\(reviewText)\nCompleted in the sample workspace; no external action taken."
    }
    /// A changed proposal must be reviewed again; old approval never carries over.
    func changeFare() {
        guard phase == .review, scenario == .ride else { return }
        fare += 5
        reviewText = reviewText.replacingOccurrences(of: "$\(fare - 5)", with: "$\(fare)")
        phase = .browsing
        schedule()
    }
    func reset() {
        cancelRunner()
        scenario = nil; phase = .idle; step = 0; receipt = nil
        reviewText = ""; patientName = ""; isCollapsed = false; fare = 24; messages = []
    }
}
