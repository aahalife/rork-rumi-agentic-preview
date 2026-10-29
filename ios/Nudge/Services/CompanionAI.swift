import Foundation

/// Minimal wire message; no private API credentials are part of this type.
nonisolated struct AIChatMessage: Codable {
    let role: String
    let content: String
}

nonisolated private struct StreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta?
    }
    let choices: [Choice]?
    let error: String?
}

nonisolated enum CompanionAIError: LocalizedError {
    case unavailable(String)
    case empty
    var errorDescription: String? {
        switch self {
        case .unavailable(let message): return message
        case .empty: return "The reply was interrupted. Please try again."
        }
    }
}

/// Streams only displayable text from Rumi’s consent-gated server connection.
final class CompanionAI {
    func stream(
        system: String,
        messages: [AIChatMessage],
        privacy: AIPrivacy,
        purpose: String = "conversation",
        onDelta: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        guard privacy.processingConsent else {
            throw CompanionAIError.unavailable("Rumi AI is turned off. You can turn it back on in Settings.")
        }
        guard let url = URL(string: "\(AppConfig.functionsURL)/ai/chat") else { throw CompanionAIError.empty }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(privacy.deviceID, forHTTPHeaderField: "X-Rumi-Device")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "context": system,
            "messages": messages.filter { !$0.content.isEmpty }.suffix(14).map { ["role": $0.role, "content": $0.content] },
            "consent": true,
            "purpose": purpose,
        ])
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let message = (response as? HTTPURLResponse)?.statusCode == 429
                ? "Rumi AI needs a short break. Please try again in a moment."
                : "Rumi AI is unavailable right now. Please try again."
            throw CompanionAIError.unavailable(message)
        }
        var full = ""
        var completed = false
        let decoder = JSONDecoder()
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let json = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if json == "[DONE]" { completed = true; continue }
            guard let data = json.data(using: .utf8), let chunk = try? decoder.decode(StreamChunk.self, from: data) else { continue }
            if chunk.error != nil { throw CompanionAIError.empty }
            guard let delta = chunk.choices?.first?.delta?.content, !delta.isEmpty else { continue }
            full += delta
            onDelta(delta)
        }
        guard completed, !full.isEmpty else { throw CompanionAIError.empty }
        return full
    }
}
