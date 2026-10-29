import Foundation
import Testing
@testable import Rumi

private final class APIStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var respond: (@Sendable (URLRequest) -> (Int, Data))?
    nonisolated override class func canInit(with request: URLRequest) -> Bool { true }
    nonisolated override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    nonisolated override func startLoading() {
        guard let (status, data) = Self.respond?(request), let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    nonisolated override func stopLoading() {}
}
private final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var items: [URLRequest] = []
    nonisolated func append(_ request: URLRequest) { lock.lock(); defer { lock.unlock() }; items.append(request) }
    nonisolated func all() -> [URLRequest] { lock.lock(); defer { lock.unlock() }; return items }
}

@MainActor @Suite(.serialized)
struct RumiAPITransportTests {
    let settings = RumiAPISettings(baseURL: "https://example.invalid/functions/v1/rumi-app-api", appID: "00000000-0000-0000-0000-000000000001")
    let challenge = RumiAPIChallenge(challenge_id: "00000000-0000-0000-0000-000000000002", status: "code_sent", delivered: true, expires_in: 300, messaging_number: nil)
    func api() throws -> RumiAppAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [APIStub.self]
        let api = RumiAppAPI(transport: URLSession(configuration: configuration), persist: false)
        try api.configure(settings)
        return api
    }
    nonisolated static func session(expired: Bool, token: String) -> Data {
        Data("{\"user_id\":\"member\",\"session_id\":\"session\",\"access_token\":\"\(String(repeating: token, count: 64))\",\"refresh_token\":\"\(String(repeating: "b", count: 64))\",\"expires_at\":\"\(expired ? "2000" : "2099")-01-01T00:00:00Z\"}".utf8)
    }
    @Test func concurrentReadsRotateRefreshOnceAndUseNewToken() async throws {
        let log = RequestLog()
        APIStub.respond = { request in
            log.append(request)
            if request.url!.path.hasSuffix("/verify") { return (200, Self.session(expired: true, token: "a")) }
            if request.url!.path.hasSuffix("/refresh") { return (200, Self.session(expired: false, token: "c")) }
            return (200, Data("{}".utf8))
        }
        defer { APIStub.respond = nil }
        let api = try api()
        try await api.verify(challenge, code: "123456")
        async let profile = api.read(.profile)
        async let goals = api.read(.goals)
        _ = try await (profile, goals)
        let requests = log.all()
        #expect(requests.filter { $0.url!.path.hasSuffix("/refresh") }.count == 1)
        for request in requests.filter({ $0.httpMethod == "GET" }) {
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer " + String(repeating: "c", count: 64))
        }
        #expect(api.authenticated)
    }
    @Test func httpErrorsDoNotExposeServiceBodyOrAuthenticate() async throws {
        APIStub.respond = { _ in (401, Data("{\"private\":\"DO_NOT_DISPLAY_TOKEN\"}".utf8)) }
        defer { APIStub.respond = nil }
        let api = try api()
        do { try await api.verify(challenge, code: "123456"); Issue.record("401 must fail") }
        catch { #expect(!error.localizedDescription.contains("DO_NOT_DISPLAY_TOKEN")) }
        #expect(!api.authenticated)
    }
    @Test func invalidSessionTokensFailClosed() async throws {
        APIStub.respond = { _ in (200, Self.session(expired: false, token: "z")) }
        defer { APIStub.respond = nil }
        let api = try api()
        do { try await api.verify(challenge, code: "123456"); Issue.record("Non-hex token must not authenticate") }
        catch { #expect(error.localizedDescription.contains("invalid session")) }
        #expect(!api.authenticated)
    }
}
