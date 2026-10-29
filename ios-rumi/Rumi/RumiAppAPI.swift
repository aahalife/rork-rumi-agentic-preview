import Foundation
import Security
import SwiftUI

private final class RumiAPINoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

// Contract: integrations/rumi-app-api/openapi.json. Independent of demo and legacy Companion.
struct RumiAPISettings: Codable, Equatable {
    let baseURL: String
    let appID: String
    // Owner-confirmed public integration metadata; never a user credential.
    static let ownerConfirmed = RumiAPISettings(
        baseURL: "https://egoicdonmuudwvbsockm.supabase.co/functions/v1/rumi-app-api",
        appID: "50594005-ee06-4087-abdf-733596f001e6"
    )
    func validatedURL() throws -> URL {
        guard let url = URL(string: baseURL), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              UUID(uuidString: appID) != nil else {
            throw CompanionError(message: "Enter the confirmed HTTPS API base URL and public app ID. The documentation URL is not necessarily the API base URL.")
        }
        return url
    }
}
struct RumiAPISession: Codable {
    let user_id: String
    let session_id: String
    let access_token: String
    let refresh_token: String
    let expires_at: String
    let refresh_expires_at: String?
    var needsRefresh: Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: expires_at) ?? ISO8601DateFormatter().date(from: expires_at)
        return date == nil || date!.timeIntervalSinceNow < 60
    }
}
struct RumiAPIChallenge: Decodable {
    let challenge_id: String
    let status: String
    let delivered: Bool?
    let expires_in: Int?
    let messaging_number: String?
}
struct RumiAPIReceipt: Decodable {
    let status: String?
    let committed: Bool?
    let receipt_id: String?
    var confirmed: Bool { committed == true }
}
struct RumiAPIConfig: Decodable {
    let api_version: String?
    let records_mode: String?
    let brand: String?
}
struct RumiAPIMemory: Decodable {
    struct Item: Decodable, Identifiable {
        struct Body: Decodable { let text: String? }
        let id: String
        let kind: String?
        let status: String?
        let body: Body?
    }
    let memory_consent: String?
    let preferred_name: String?
    let items: [Item]?
}
// Preserve loosely specified records/context without guessing their medical meaning or test/live mode.
indirect enum RumiJSON: Codable {
    case object([String: RumiJSON]), array([RumiJSON]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let value = try? c.decode(Bool.self) { self = .bool(value) }
        else if let value = try? c.decode(String.self) { self = .string(value) }
        else if let value = try? c.decode(Double.self) { self = .number(value) }
        else if let value = try? c.decode([String: RumiJSON].self) { self = .object(value) }
        else { self = .array(try c.decode([RumiJSON].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .object(let x): try c.encode(x); case .array(let x): try c.encode(x); case .string(let x): try c.encode(x); case .number(let x): try c.encode(x); case .bool(let x): try c.encode(x); case .null: try c.encodeNil() }
    }
    var formatted: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "Unavailable"
    }
}

@MainActor @Observable
final class RumiAppAPI {
    static let shared = RumiAppAPI()
    private(set) var settings: RumiAPISettings?
    private(set) var authenticated = false
    private(set) var identity = UUID()
    private var session: RumiAPISession?
    private var refreshTask: Task<RumiAPISession, Error>?
    private let transport: URLSession
    private let persist: Bool
    private let settingsKey = "rumi.app-api.settings.v1"
    private static let keychainService = "com.rumi.app-api.session.v1"
    init(transport: URLSession? = nil, persist: Bool = true) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil; configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
        self.transport = transport ?? URLSession(configuration: configuration, delegate: RumiAPINoRedirectDelegate(), delegateQueue: nil); self.persist = persist
        if persist { settings = .ownerConfirmed }
        if persist, let data = UserDefaults.standard.data(forKey: settingsKey), let value = try? JSONDecoder().decode(RumiAPISettings.self, from: data), (try? value.validatedURL()) != nil {
            settings = value
            var item: CFTypeRef?
            if SecItemCopyMatching([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Self.keychainService, kSecAttrAccount as String: "session", kSecReturnData as String: true] as CFDictionary, &item) == errSecSuccess, let data = item as? Data {
                session = try? JSONDecoder().decode(RumiAPISession.self, from: data); authenticated = session != nil
            }
        }
    }
    func configure(_ settings: RumiAPISettings) throws {
        try allowed()
        _ = try settings.validatedURL()
        if self.settings != settings { disconnect(); self.settings = settings }
        if persist { UserDefaults.standard.set(try JSONEncoder().encode(settings), forKey: settingsKey) }
    }
    func disconnect() {
        refreshTask?.cancel(); refreshTask = nil; identity = UUID(); session = nil; authenticated = false
        if persist { SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Self.keychainService] as CFDictionary) }
    }
    private func allowed() throws {
        guard !DemoSession.shared.isPresented else { throw CompanionError(message: "Existing-account API requests are blocked while demo mode is open.") }
    }
    static func makeRequest(settings: RumiAPISettings, path: String, method: String = "GET", body: [String: String]? = nil, token: String? = nil, idempotencyKey: String? = nil) throws -> URLRequest {
        guard path.hasPrefix("v1/") || path == "health", !path.contains(".."), !path.contains("?"), !path.contains("#"), !path.contains("://") else { throw CompanionError(message: "Unsupported API route.") }
        let base = try settings.validatedURL()
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = method; request.timeoutInterval = 30
        request.setValue(settings.appID, forHTTPHeaderField: "x-rumi-app-id")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let idempotencyKey { request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return request
    }
    private func perform<T: Decodable>(_ path: String, method: String = "GET", body: [String: String]? = nil, token: String? = nil, idempotencyKey: String? = nil) async throws -> T {
        try allowed()
        guard let settings else { throw CompanionError(message: "The App API is not configured yet. Await the confirmed base URL and public app ID.") }
        let version = identity
        let request = try Self.makeRequest(settings: settings, path: path, method: method, body: body, token: token, idempotencyKey: idempotencyKey)
        let (data, response) = try await transport.data(for: request)
        try Task.checkCancellation(); try allowed()
        guard identity == version else { throw CompanionError(message: "The API account changed. Reopen this screen.") }
        guard let http = response as? HTTPURLResponse else { throw CompanionError(message: "No API response was received.") }
        guard (200..<300).contains(http.statusCode) else {
            // Do not expose raw bodies, tokens, signed URLs or provider messages.
            throw CompanionError(message: http.statusCode == 401 ? "Your Rumi session is unavailable or expired. Sign in again." : http.statusCode == 429 ? "Rumi is rate limiting requests. Please wait before trying again." : "Rumi App API could not complete this request (HTTP \(http.statusCode)).")
        }
        guard data.count <= 2_000_000 else { throw CompanionError(message: "The API response exceeded this app’s safe size limit.") }
        return try JSONDecoder().decode(T.self, from: data)
    }
    private func store(_ value: RumiAPISession) throws {
        guard value.access_token.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
              value.refresh_token.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else { throw CompanionError(message: "Rumi returned an invalid session.") }
        if persist {
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Self.keychainService, kSecAttrAccount as String: "session"]
            let data = try JSONEncoder().encode(value)
            let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if update == errSecItemNotFound {
                var add = query; add[kSecValueData as String] = data; add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
                guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { throw CompanionError(message: "The Rumi session could not be saved securely.") }
            } else if update != errSecSuccess { throw CompanionError(message: "The secure Rumi session could not be updated.") }
        }
        session = value; authenticated = true
    }
    private func accessToken() async throws -> String {
        try allowed()
        guard let session else { throw CompanionError(message: "Sign in to your existing Rumi account first.") }
        if !session.needsRefresh { return session.access_token }
        if let refreshTask {
            let version = identity
            let next = try await refreshTask.value
            guard identity == version else { throw CancellationError() }
            return next.access_token
        }
        let version = identity
        let task = Task<RumiAPISession, Error> { [self] in
            let next: RumiAPISession = try await perform("v1/auth/refresh", method: "POST", body: ["refresh_token": session.refresh_token])
            guard identity == version else { throw CancellationError() }
            try store(next)
            return next
        }
        refreshTask = task
        do { let next = try await task.value; guard identity == version else { throw CancellationError() }; refreshTask = nil; return next.access_token }
        catch { if identity == version { disconnect() }; throw error }
    }
    func config() async throws -> RumiAPIConfig { try await perform("v1/config") }
    func health() async throws -> RumiJSON { try await perform("health") }
    func challenge(phone: String) async throws -> RumiAPIChallenge {
        guard phone.range(of: "^\\+[1-9]\\d{7,14}$", options: .regularExpression) != nil else { throw CompanionError(message: "Use an international phone number, starting with +.") }
        return try await perform("v1/auth/challenges", method: "POST", body: ["phone_number": phone])
    }
    func resend(_ challenge: RumiAPIChallenge) async throws -> RumiAPIChallenge {
        guard UUID(uuidString: challenge.challenge_id) != nil else { throw CompanionError(message: "Invalid challenge.") }
        return try await perform("v1/auth/challenges/\(challenge.challenge_id)/send", method: "POST", body: [:])
    }
    func verify(_ challenge: RumiAPIChallenge, code: String) async throws {
        guard UUID(uuidString: challenge.challenge_id) != nil, code.range(of: "^\\d{6}$", options: .regularExpression) != nil else { throw CompanionError(message: "Enter the six-digit code from your Rumi message thread.") }
        let value: RumiAPISession = try await perform("v1/auth/challenges/\(challenge.challenge_id)/verify", method: "POST", body: ["code": code])
        try store(value); identity = UUID()
    }
    enum Resource: String, CaseIterable, Identifiable {
        case profile = "me", context, records, memory, goals, actions, questions = "visit-questions", calls = "call-preferences", connections, messaging = "messaging/status", conversations
        var id: String { rawValue }
    }
    func read(_ resource: Resource) async throws -> RumiJSON {
        let token = try await accessToken()
        return try await perform("v1/" + resource.rawValue, token: token)
    }
    func memory() async throws -> RumiAPIMemory { let token = try await accessToken(); return try await perform("v1/memory", token: token) }
    func saveGoal(_ text: String, id: String) async throws -> RumiAPIReceipt {
        guard (1...2000).contains(text.count) else { throw CompanionError(message: "A goal must contain 1–2,000 characters.") }
        let token = try await accessToken()
        return try await perform("v1/goals", method: "POST", body: ["text": text, "quote": text], token: token, idempotencyKey: id)
    }
    func logout() async throws {
        let token = try await accessToken()
        let _: RumiAPIReceipt = try await perform("v1/auth/logout", method: "POST", body: [:], token: token)
        disconnect()
    }
}
