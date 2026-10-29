import Foundation
import Security
import SwiftUI

struct CompanionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// The phone stores an individual, revocable account token, never a provider API key.
@MainActor @Observable
final class CompanionConnection {
    static let shared = CompanionConnection()
    var endpoint: String = UserDefaults.standard.string(forKey: "rumi.service.endpoint") ?? "https://rumi-cvs-agentic-backend.rork.app"
    private(set) var connected: Bool
    private(set) var identityVersion = UUID()
    private init() { connected = Self.token() != nil }
    private static let service = "com.rumi.companion.access"
    private static func token() -> String? {
        var item: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "account", kSecReturnData as String: true]
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    func save(endpoint: String, token: String) throws {
        guard let url = URL(string: endpoint), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil, url.query == nil, url.fragment == nil, url.path.isEmpty || url.path == "/" else { throw CompanionError(message: "Use the HTTPS address of your Rumi service, without a path.") }
        guard token.range(of: "^[A-Za-z0-9_-]{32,256}$", options: .regularExpression) != nil else { throw CompanionError(message: "Enter the individual access token issued for your account, not a provider API key.") }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Self.service, kSecAttrAccount as String: "account"]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = Data(token.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { throw CompanionError(message: "Your account access could not be saved securely.") }
        self.endpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        UserDefaults.standard.set(self.endpoint, forKey: "rumi.service.endpoint")
        connected = true
        identityVersion = UUID()
    }
    func disconnect() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Self.service] as CFDictionary)
        connected = false
        identityVersion = UUID()
    }
    func request<T: Decodable>(_ path: String, body: [String: Any]? = nil, as type: T.Type = T.self) async throws -> T {
        let identity = identityVersion
        guard let token = Self.token(), let url = URL(string: endpoint + "/companion/" + path), url.scheme == "https" else { throw CompanionError(message: "Connect your Rumi account in Menu → Account to use this feature.") }
        var request = URLRequest(url: url)
        request.httpMethod = body == nil ? "GET" : "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = path == "chat" ? 150 : 60
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard identityVersion == identity else { throw CompanionError(message: "Your account changed. Reopen this screen to use the current account.") }
        guard let http = response as? HTTPURLResponse else { throw CompanionError(message: "The Rumi service did not respond.") }
        guard (200..<300).contains(http.statusCode) else {
            let problem = try? JSONDecoder().decode(ServiceProblem.self, from: data)
            throw CompanionError(message: problem?.error ?? "Rumi could not connect (\(http.statusCode)). Please try again.")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    func voiceRequest(address: String) throws -> URLRequest {
        guard let token = Self.token(), let url = URL(string: address), let serviceURL = URL(string: endpoint),
              url.scheme == "wss", url.host == serviceURL.host, url.port == serviceURL.port,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.hasPrefix("/companion/voice/socket/") else { throw CompanionError(message: "The voice connection does not belong to your Rumi service.") }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
    private struct ServiceProblem: Decodable { let error: String }
}

struct CompanionStatus: Decodable {
    let model: String
    let browser: Bool
    let voice: Bool
    let calls: Bool
    let imessage: Bool
    let chat: Bool?
    let conversationService: String?
    let historyNotice: String?
    let sharedBackend: Bool?
    let sharedContext: Bool?
}
struct ServiceOK: Decodable { let ok: Bool }
struct RemoteConversation: Decodable {
    struct Entry: Decodable { let id: String; let role: String; let text: String; let source: String }
    let messages: [Entry]
}

struct CompanionAccountView: View {
    @State private var connection = CompanionConnection.shared
    @State private var endpoint = CompanionConnection.shared.endpoint
    @State private var token = ""
    @State private var status: CompanionStatus?
    @State private var error: String?
    @State private var busy = false
    @State private var showDisconnect = false
    var body: some View {
        Form {
            Section {
                TextField("Service address", text: $endpoint).textContentType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField(connection.connected ? "Replacement account token" : "Account access token", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive()
                Button(busy ? "Connecting…" : "Connect securely") {
                    busy = true; error = nil
                    Task {
                        do {
                            try connection.save(endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines), token: token.trimmingCharacters(in: .whitespacesAndNewlines))
                            token = ""
                            status = try await connection.request("status")
                        } catch { self.error = error.localizedDescription }
                        busy = false
                    }
                }.disabled(busy || token.isEmpty)
            } header: { Text("Rumi connection") } footer: { Text("Use your individual Rumi account token. ElevenLabs, Photon and model API keys belong only in the server’s secret settings, never here.") }
            if let status {
                Section("Services") {
                    LabeledContent("Browser", value: status.browser ? "Configured" : "Needs setup")
                    LabeledContent("Chat", value: (status.chat ?? status.browser) ? "Configured" : "Needs setup")
                    if let service = status.conversationService { LabeledContent("Conversation", value: service) }
                    LabeledContent("Voice", value: status.voice ? "Configured" : "Needs setup")
                    LabeledContent("Calls", value: status.calls ? "Configured" : "Needs setup")
                    LabeledContent(status.sharedBackend == true ? "iMessage owner" : "Photon v2 app sync", value: status.sharedBackend == true ? "Shared backend" : status.imessage ? "Configured" : "Not connected")
                    if status.sharedBackend == true {
                        NavigationLink("Saved context & permissions") { SharedContextView() }
                    }
                    if let notice = status.historyNotice { Text(notice).font(.footnote).foregroundStyle(.secondary) }
                }
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            Section {
                NavigationLink("Calls & iMessage") { CompanionChannelsView() }
                if connection.connected { Button("Disconnect this device", role: .destructive) { showDisconnect = true } }
            }
        }
        .navigationTitle("Account")
        .task { if connection.connected { do { status = try await connection.request("status") } catch { self.error = error.localizedDescription } } }
        .confirmationDialog("Disconnect this device?", isPresented: $showDisconnect, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) { connection.disconnect(); status = nil }
        } message: { Text("This removes device access only. Cancel scheduled calls and unlink iMessage first if you want those to stop too.") }
    }
}
