import Foundation
import WebKit

/// Offline maintained AI SDK codec. No auth, microphone or web pages enter this WebView.
@MainActor
final class DemoRealtimeCodec: NSObject, WKNavigationDelegate {
    private var web: WKWebView?
    private var ready: CheckedContinuation<Void, Error>?
    func load() async throws {
        guard let file = Bundle.main.url(forResource: "DemoRealtimeCodec", withExtension: "js") else { throw CompanionError(message: "The realtime codec is missing from this build.") }
        let source = try String(contentsOf: file, encoding: .utf8)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = self
        web = view
        try await withCheckedThrowingContinuation { continuation in
            ready = continuation
            view.loadHTMLString("<!doctype html><meta http-equiv='Content-Security-Policy' content=\"default-src 'none'; script-src 'unsafe-inline'; connect-src 'none'\"><title>Offline realtime codec</title>", baseURL: nil)
        }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { ready?.resume(); ready = nil }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { ready?.resume(throwing: error); ready = nil }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { ready?.resume(throwing: error); ready = nil }
    func encode(_ event: [String: Any]) async throws -> String {
        guard let web else { throw CompanionError(message: "The realtime codec is not ready.") }
        let data = try JSONSerialization.data(withJSONObject: event)
        let result = try await web.callAsyncJavaScript("return await RumiDemoCodec.encode(event)", arguments: ["event": String(decoding: data, as: UTF8.self)], in: nil, contentWorld: .page)
        guard let result = result as? String else { throw CompanionError(message: "The realtime codec could not encode an event.") }
        return result
    }
    func decode(_ text: String) async throws -> [[String: Any]] {
        guard let web else { throw CompanionError(message: "The realtime codec is not ready.") }
        let result = try await web.callAsyncJavaScript("return RumiDemoCodec.decode(event)", arguments: ["event": text], in: nil, contentWorld: .page)
        guard let result = result as? String, let data = result.data(using: .utf8), let events = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw CompanionError(message: "The realtime codec could not read an event.") }
        return events
    }
    func close() {
        ready?.resume(throwing: CancellationError()); ready = nil
        web?.stopLoading(); web?.navigationDelegate = nil; web = nil
    }
}

@MainActor
final class DemoSocketDelegate: NSObject, URLSessionWebSocketDelegate {
    var onOpen: (() -> Void)?
    var onClose: (() -> Void)?
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Task { @MainActor in self.onOpen?(); self.onOpen = nil }
    }
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor in self.onClose?() }
    }
}
