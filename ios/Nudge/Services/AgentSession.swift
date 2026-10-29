import Foundation
import Observation

/// Adapts the repository's WebSocket protocol to Rumi. Only the isolated portal browser executes tools.
@MainActor
@Observable
final class AgentSession {
    enum State: String {
        case disconnected, idle, thinking, acting, waitingForUser
        init(wire: String) {
            switch wire {
            case "thinking": self = .thinking
            case "acting": self = .acting
            case "waiting_for_user": self = .waitingForUser
            default: self = .idle
            }
        }
    }

    struct ChatMessage: Identifiable {
        enum Role { case patient, assistant }
        let id: UUID = UUID()
        let role: Role
        let text: String
    }
    struct PendingConfirm: Identifiable {
        let id: String
        let summary: String
    }

    private(set) var messages: [ChatMessage] = []
    private(set) var state: State = .disconnected
    private(set) var pendingConfirm: PendingConfirm?
    private(set) var step: Int = 0
    private(set) var connectionNote: String?
    var isRunning: Bool { state == .thinking || state == .acting || pendingConfirm != nil }
    var statusLabel: String {
        switch state {
        case .disconnected: "Not connected"
        case .idle: "Ready to help"
        case .thinking: "Considering your request"
        case .acting: "Working in the portal"
        case .waitingForUser: pendingConfirm == nil ? "Your turn" : "Needs your okay"
        }
    }

    let bridge: AgentBridge
    let backendURL: URL
    private let demoKey: String
    private let client: URLSession = URLSession(configuration: .ephemeral)
    private var socket: URLSessionWebSocketTask?
    private var connectionTask: Task<Void, Never>?
    private var actionTask: Task<Void, Never>?
    private var acceptsActions: Bool = false
    private var approvedClick: Bool = false
    private var generation: UUID = UUID()

    init(backendURL: URL, demoKey: String, bridge: AgentBridge) {
        self.backendURL = backendURL
        self.demoKey = demoKey
        self.bridge = bridge
    }

    func start() {
        guard connectionTask == nil else { return }
        let attempt = UUID()
        generation = attempt
        connectionNote = nil
        connectionTask = Task {
            do {
                var request = URLRequest(url: backendURL.appending(path: "agent/sessions"))
                request.httpMethod = "POST"
                request.timeoutInterval = 15
                request.setValue(demoKey, forHTTPHeaderField: "X-Demo-Key")
                let (data, response) = try await client.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                let created = try JSONDecoder().decode(CreatedSession.self, from: data)
                guard generation == attempt, !Task.isCancelled else { return }
                var parts = URLComponents(url: backendURL.appending(path: "agent/ws"), resolvingAgainstBaseURL: false)
                parts?.scheme = "wss"
                parts?.queryItems = [URLQueryItem(name: "session_id", value: created.session_id)]
                guard let url = parts?.url else { throw URLError(.badURL) }
                var handshake = URLRequest(url: url)
                handshake.setValue(created.session_token, forHTTPHeaderField: "X-Agent-Token")
                let task = client.webSocketTask(with: handshake)
                socket = task
                task.resume()
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    task.sendPing { error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume() }
                    }
                }
                guard generation == attempt, !Task.isCancelled else { return }
                state = .idle
                while !Task.isCancelled {
                    let incoming = try await task.receive()
                    guard generation == attempt else { return }
                    let bytes: Data
                    switch incoming {
                    case .string(let text): bytes = Data(text.utf8)
                    case .data(let data): bytes = data
                    @unknown default: continue
                    }
                    if let message = try? JSONDecoder().decode(ServerMessage.self, from: bytes) { handle(message) }
                }
            } catch {
                guard generation == attempt, !Task.isCancelled else { return }
                disconnect()
                connectionNote = "Connection interrupted. Reconnect, inspect the portal, and ask again. An uncertain submission is never repeated automatically."
            }
        }
    }

    func disconnect() {
        generation = UUID()
        acceptsActions = false
        approvedClick = false
        bridge.cancelPendingActions()
        actionTask?.cancel(); actionTask = nil
        connectionTask?.cancel(); connectionTask = nil
        socket?.cancel(with: .goingAway, reason: nil); socket = nil
        pendingConfirm = nil
        state = .disconnected
    }

    /// Stop closes the old session so delayed actions cannot join the next request.
    func stop() {
        disconnect()
        connectionNote = "Stopped. This cannot undo a request already submitted. Review the portal before asking again."
    }

    func sendUserMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 4000, state != .disconnected, !isRunning else { return }
        acceptsActions = true
        approvedClick = false
        connectionNote = nil
        messages.append(ChatMessage(role: .patient, text: trimmed))
        state = .thinking
        send(.userMessage(text: trimmed))
    }

    func respondToConfirm(allowed: Bool) {
        guard acceptsActions, let pending = pendingConfirm else { return }
        pendingConfirm = nil
        approvedClick = allowed
        if !allowed {
            // Denial stops the entire task, rather than allowing alternative submission routes.
            send(.confirmResponse(id: pending.id, allowed: false, reason: "Patient declined."))
            stop()
            return
        }
        state = .acting
        send(.confirmResponse(id: pending.id, allowed: true, reason: nil))
    }

    private func send(_ message: ClientMessage) {
        guard let task = socket else { return }
        let attempt = generation
        Task {
            do {
                guard attempt == generation else { return }
                let bytes = try JSONEncoder().encode(message)
                try await task.send(.string(String(decoding: bytes, as: UTF8.self)))
            } catch {
                guard attempt == generation else { return }
                disconnect()
                connectionNote = "Couldn’t send. Reconnect and review the portal before retrying."
            }
        }
    }

    private func handle(_ message: ServerMessage) {
        guard acceptsActions else { return }
        switch message {
        case .requestObservation(let id):
            runAction {
                let observation = try await self.bridge.snapshotWithRetry()
                try Task.checkCancellation()
                self.send(.observation(id: id, observation: observation))
            }
        case .actionRequest(let id, let action, let args, _):
            runAction {
                var errorText: String?
                do {
                    if action == "click" {
                        let page = try await self.bridge.snapshotWithRetry()
                        let element = page.elements.first { $0.ref == args["ref"]?.intValue }
                        let consequential = PortalActionPolicy.needsApproval(element: element, args: args)
                        if consequential {
                            guard self.approvedClick, args["expected_page"] != nil else {
                                throw BridgeError.refused("This submission needs a fresh approval.")
                            }
                            self.approvedClick = false
                        }
                    }
                    try await self.bridge.perform(action, args)
                } catch is CancellationError { return }
                catch { errorText = "Browser action refused or interrupted. Inspect the current page before retrying." }
                try Task.checkCancellation()
                let observation = try await self.bridge.snapshotWithRetry()
                try Task.checkCancellation()
                self.send(.actionResult(id: id, ok: errorText == nil, error: errorText, observation: observation))
            }
        case .requestScreenshot(let id):
            runAction {
                let image = (try? await self.bridge.screenshotBase64()) ?? ""
                try Task.checkCancellation()
                self.send(.screenshot(id: id, jpegBase64: image))
            }
        case .confirmRequest(let id, let summary):
            approvedClick = false
            pendingConfirm = PendingConfirm(id: id, summary: summary)
            state = .waitingForUser
        case .agentMessage(let text, let delta):
            if !delta { messages.append(ChatMessage(role: .assistant, text: text)) }
        case .status(let wire, let step, _):
            self.step = step
            state = State(wire: wire)
            if pendingConfirm != nil { state = .waitingForUser }
        case .done(let summary):
            acceptsActions = false
            approvedClick = false
            pendingConfirm = nil
            messages.append(ChatMessage(role: .assistant, text: summary))
            state = .idle
        case .error(_, let fatal):
            connectionNote = "Rumi couldn’t finish this request. Check the portal before trying again."
            if fatal { stop() }
        case .unknown: break
        }
    }

    private func runAction(_ work: @escaping @MainActor () async throws -> Void) {
        bridge.cancelPendingActions()
        actionTask?.cancel()
        let attempt = generation
        actionTask = Task {
            do { try await work() }
            catch is CancellationError { }
            catch {
                guard generation == attempt else { return }
                stop()
                connectionNote = "The browser is unavailable. Inspect or reload the page, then reconnect. No action will be replayed."
            }
        }
    }
}

nonisolated private struct CreatedSession: Decodable {
    let session_id: String
    let session_token: String
}
