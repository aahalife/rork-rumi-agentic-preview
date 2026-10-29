import SwiftUI
import WebKit

@MainActor @Observable
final class WorksModel {
    enum Control: String { case user = "You’re in control", working = "Rumi is working", paused = "Paused", review = "Needs your approval" }
    struct Message: Identifiable { let id = UUID(); let user: Bool; let text: String }
    struct Recipe: Identifiable, Codable {
        let id: UUID
        let title: String
        let url: String
        let ingredients: String
        let savedAt: Date
    }
    struct Proposal: Identifiable {
        let id = UUID()
        let action: WorksAction
        let observation: WorksObservation
        let signature: String
        let summary: String
        let run: UUID
    }
    var includeContext = true
    var expanded = true
    var browserOnly = false
    var reviewPresented = false
    var browserError: String?
    var address = "https://www.google.com"
    var pageTitle = "Browse with Rumi"
    var loading = false
    var canGoBack = false
    var canGoForward = false
    private(set) var control: Control = .user
    private(set) var pending: Proposal?
    private(set) var messages = [Message(user: false, text: "Open a website, then tell me what you’d like to do. You can browse yourself or ask me to help with the page.")]
    private(set) var saved: [Recipe] = []
    @ObservationIgnored var webView: WKWebView?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var run = UUID()
    @ObservationIgnored private var objective: String?
    @ObservationIgnored private var history: [[String: String]] = []
    @ObservationIgnored private var lastSignature = ""
    @ObservationIgnored private var repeats = 0
    @ObservationIgnored private var capturing = false
    private let savedKey = "rumi.works.real-recipes.v1"
    var hasActivity: Bool { messages.count > 1 }
    init() {
        if let data = UserDefaults.standard.data(forKey: savedKey), let items = try? JSONDecoder().decode([Recipe].self, from: data) { saved = items }
    }
    func say(_ text: String, user: Bool = false) { messages.append(Message(user: user, text: text)) }
    private func invalidate() {
        task?.cancel(); task = nil; run = UUID(); pending = nil; reviewPresented = false
    }
    func takeControl() { invalidate(); control = .user }
    func pause() { invalidate(); control = .paused }
    func stop() { pause(); objective = nil; say("Stopped. Any action already dispatched may still finish on the website; review the page before trying it again.") }
    func pageChanged() {
        if pending != nil { pause(); say("The page changed, so I cancelled that proposal. Resume when you’re ready for a fresh review.") }
    }
    func resume() { guard let objective else { control = .user; return }; ask(objective, repeatRequest: true) }
    static func website(_ input: String) throws -> URL {
        let clean = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = clean.contains("://") ? clean : "https://" + clean
        guard let url = URL(string: value), url.scheme == "https", let host = url.host?.lowercased(), url.user == nil, url.password == nil,
              host.contains("."), host != "localhost", !host.hasSuffix(".local"), !host.hasSuffix(".internal"), !host.hasSuffix(".localhost"),
              !host.contains(":"), host.range(of: "^[0-9.]+$", options: .regularExpression) == nil else { throw CompanionError(message: "Enter a public HTTPS website address. Local addresses and non-secure sites aren’t supported.") }
        return url
    }
    func navigate(_ input: String) {
        takeControl()
        do { let url = try Self.website(input); browserError = nil; address = url.absoluteString; webView?.load(URLRequest(url: url)) }
        catch { browserError = error.localizedDescription }
    }
    func back() { takeControl(); webView?.goBack() }
    func forward() { takeControl(); webView?.goForward() }
    func reload() { takeControl(); browserError = nil; webView?.reload() }
    func clearWebsiteData() {
        takeControl()
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { }
        webView?.load(URLRequest(url: URL(string: "https://www.google.com")!))
        say("Website sign-ins and browsing data are being cleared on this device.")
    }
    func openRecipe(_ recipe: Recipe) { navigate(recipe.url) }
    func removeRecipe(_ id: UUID) { saved.removeAll { $0.id == id }; persistRecipes() }
    private func persistRecipes() { if let data = try? JSONEncoder().encode(saved) { UserDefaults.standard.set(data, forKey: savedKey) } }
    private func observe() async throws -> WorksObservation {
        guard let webView, !webView.isLoading, let url = webView.url else { throw CompanionError(message: "Wait for the website to finish loading, then resume.") }
        _ = try Self.website(url.absoluteString)
        let json = try await WorksBridge.call(webView, method: "snapshot")
        return try JSONDecoder().decode(WorksObservation.self, from: Data(json.utf8))
    }
    private func signature(_ observation: WorksObservation) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(observation), as: UTF8.self)
    }
    private func screenshot(_ observation: WorksObservation) async throws -> String {
        guard !capturing else { throw CompanionError(message: "A page image is still being captured. Resume in a moment.") }
        guard let webView, !observation.sensitive else { throw CompanionError(message: "Visual context is unavailable on a page with private fields. Sign in yourself, then continue.") }
        capturing = true
        defer { capturing = false }
        _ = try await WorksBridge.call(webView, method: "mask", arguments: ["on": true])
        do {
            let config = WKSnapshotConfiguration(); config.snapshotWidth = 900
            let image = try await webView.takeSnapshot(configuration: config)
            _ = try? await WorksBridge.call(webView, method: "mask", arguments: ["on": false])
            guard let data = image.jpegData(compressionQuality: 0.5), data.count < 500000 else { throw CompanionError(message: "This page image is too large. Try reading a smaller part of the page.") }
            return data.base64EncodedString()
        } catch { _ = try? await WorksBridge.call(webView, method: "mask", arguments: ["on": false]); throw error }
    }
    func ask(_ text: String, repeatRequest: Bool = false) {
        let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(6000))
        guard !clean.isEmpty else { return }
        invalidate(); objective = clean
        if !repeatRequest { say(clean, user: true); history = []; repeats = 0; lastSignature = "" }
        let token = run; control = .working
        task = Task { [weak self] in
            guard let self else { return }
            do { try await self.loop(clean, token: token) }
            catch {
                guard self.run == token, !Task.isCancelled else { return }
                self.control = .paused
                self.say(error.localizedDescription)
            }
        }
    }
    private func loop(_ goal: String, token: UUID) async throws {
        var image: String?
        var imageSignature: String?
        for _ in 0..<20 {
            try Task.checkCancellation(); guard run == token else { return }
            if !includeContext {
                struct Reply: Decodable { let text: String }
                let reply: Reply = try await CompanionConnection.shared.request("chat", body: ["text": goal, "id": UUID().uuidString])
                guard run == token, !Task.isCancelled else { return }
                say(reply.text); control = .user; return
            }
            guard UserDefaults.standard.bool(forKey: "rumi.page-context.consent.v1") else { throw CompanionError(message: "Send a page question and allow page context before resuming with this website.") }
            let observation = try await observe()
            if image != nil, try signature(observation) != imageSignature { image = nil; imageSignature = nil }
            let conversation = messages.suffix(6).map { ["speaker": $0.user ? "user" : "assistant", "text": String($0.text.prefix(1000))] }
            let recipes = saved.suffix(3).map { ["savedRecipe": $0.title, "source": $0.url, "ingredients": String($0.ingredients.prefix(1200))] }
            let steps = history.suffix(8).map { $0.mapValues { String($0.prefix(900)) } }
            var request: [String: Any] = ["objective": goal, "observation": try observation.json(), "consent": true, "history": conversation + recipes + steps]
            if let image { request["screenshot"] = image }
            let action: WorksAction = try await CompanionConnection.shared.request("browser-step", body: request)
            try Task.checkCancellation(); guard run == token else { return }
            let fresh = try await observe()
            guard try signature(fresh) == signature(observation) else {
                history.append(["result": "Page changed during reasoning. Use this new observation."]); image = nil; continue
            }
            let actionData = String(decoding: try JSONEncoder().encode(action), as: UTF8.self)
            if actionData == lastSignature { repeats += 1 } else { repeats = 0; lastSignature = actionData }
            guard repeats < 2 else { throw CompanionError(message: "I’m not making progress on this page. Take control, then ask me to continue.") }
            history.append(["proposal": actionData])
            if action.kind == "visual_click", image == nil {
                history.append(["result": "Request a fresh screenshot before proposing a visual click."]); continue
            }
            if action.needsApproval {
                let detail: String
                if action.kind == "navigate" {
                    guard let url = action.url else { throw CompanionError(message: "A website address is missing.") }
                    detail = "Open: \(try Self.website(url).absoluteString)"
                } else {
                    guard let webView else { return }
                    detail = try await WorksBridge.call(webView, method: "describe", arguments: ["action": try WorksBridge.dictionary(action)])
                }
                guard run == token, !Task.isCancelled else { return }
                // Bind exact action, current observation, document revision and run. Every mutation is reviewed.
                pending = Proposal(action: action, observation: observation, signature: try signature(observation), summary: "\(action.summary)\n\nAction: \(action.kind)\nWebsite: \(observation.url)\n\n\(detail)" + (action.text.map { "\n\nExact value:\n\($0)" } ?? ""), run: token)
                control = .review; reviewPresented = true; return
            }
            switch action.kind {
            case "done", "ask_user":
                say(action.text ?? action.summary); control = action.kind == "done" ? .user : .paused
                if action.kind == "done" { objective = nil }
                return
            case "screenshot":
                image = try await screenshot(observation); imageSignature = try signature(observation)
                history.append(["result": "Masked screenshot of the current viewport attached. Coordinates use CSS viewport width/height."])
            case "scroll":
                guard let webView else { return }
                _ = try await WorksBridge.call(webView, method: "perform", arguments: ["action": try WorksBridge.dictionary(action), "expected": try WorksBridge.dictionary(observation)])
                image = nil; history.append(["result": "Scrolled; inspect the new page."])
            case "wait": try await Task.sleep(for: .seconds(1)); image = nil
            case "save_recipe":
                let recipe = Recipe(id: UUID(), title: observation.title, url: observation.url, ingredients: String((action.text ?? "").prefix(6000)), savedAt: Date())
                saved.removeAll { $0.url == recipe.url }; saved.append(recipe); persistRecipes()
                history.append(["result": "Saved the current source and extracted ingredients on this device."])
                say("Saved \(recipe.title) to My recipes.")
            default: throw CompanionError(message: "This step isn’t supported. You can use the page yourself.")
            }
            try await Task.sleep(for: .milliseconds(400))
        }
        control = .paused; say("I’ve paused after 20 steps. Check the page, then resume if you’d like me to continue.")
    }
    func approve(_ proposal: Proposal) {
        guard pending?.id == proposal.id, proposal.run == run, control == .review else { return }
        pending = nil; reviewPresented = false; control = .working
        let token = run
        task = Task { [weak self] in
            guard let self, let webView = self.webView else { return }
            do {
                let fresh = try await self.observe()
                try Task.checkCancellation()
                guard self.run == token else { return }
                guard try self.signature(fresh) == proposal.signature else { throw CompanionError(message: "That proposal is out of date. Resume for a fresh review.") }
                if proposal.action.kind == "navigate" {
                    let url = try Self.website(proposal.action.url ?? "")
                    _ = url // Validate the public HTTPS destination before the isolated-world freshness guard.
                    _ = try await WorksBridge.call(webView, method: "perform", arguments: ["action": try WorksBridge.dictionary(proposal.action), "expected": try WorksBridge.dictionary(proposal.observation)])
                    self.history.append(["result": "Navigation requested. Verify the destination loaded."])
                } else {
                    let result = try await WorksBridge.call(webView, method: "perform", arguments: ["action": try WorksBridge.dictionary(proposal.action), "expected": try WorksBridge.dictionary(proposal.observation)])
                    self.history.append(["result": result])
                }
                try await Task.sleep(for: .milliseconds(750))
                for _ in 0..<30 { if !webView.isLoading { break }; try await Task.sleep(for: .milliseconds(300)) }
                guard self.run == token, let objective = self.objective else { return }
                try await self.loop(objective, token: token)
            } catch {
                guard self.run == token, !Task.isCancelled else { return }
                self.history.append(["result": "The last action was not confirmed. Inspect the fresh page before retrying; do not repeat an external submission blindly."])
                self.control = .paused; self.say(error.localizedDescription)
            }
        }
    }
    func decline() { takeControl(); objective = nil; say("Declined. That proposed action was not executed.") }
}
