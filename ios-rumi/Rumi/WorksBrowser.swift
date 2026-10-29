import SwiftUI
import WebKit

struct WorksBrowser: UIViewRepresentable {
    let model: WorksModel
    func makeCoordinator() -> Coordinator { Coordinator(model) }
    func makeUIView(context: Context) -> WKWebView {
        let browser: WKWebView
        if let retained = model.webView { browser = retained }
        else {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .default()
            configuration.userContentController.addUserScript(WKUserScript(source: WorksBridge.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: WorksBridge.world))
            browser = WKWebView(frame: .zero, configuration: configuration)
            browser.allowsBackForwardNavigationGestures = true
            model.webView = browser
        }
        let content = browser.configuration.userContentController
        content.removeScriptMessageHandler(forName: "rumiBrowser", contentWorld: WorksBridge.world)
        content.add(context.coordinator, contentWorld: WorksBridge.world, name: "rumiBrowser")
        browser.navigationDelegate = context.coordinator
        browser.uiDelegate = context.coordinator
        if browser.url == nil, let url = try? WorksModel.website(model.address) { browser.load(URLRequest(url: url)) }
        return browser
    }
    func updateUIView(_ view: WKWebView, context: Context) { context.coordinator.model = model }
    @MainActor final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        weak var model: WorksModel?
        init(_ model: WorksModel) { self.model = model }
        private func update(_ web: WKWebView) {
            model?.address = web.url?.absoluteString ?? model?.address ?? ""
            model?.pageTitle = web.title ?? "Website"
            model?.loading = web.isLoading
            model?.canGoBack = web.canGoBack; model?.canGoForward = web.canGoForward
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, let payload = message.body as? [String: String] else { return }
            if payload["type"] == "takeover" { model?.takeControl() }
            if payload["type"] == "changed" { model?.pageChanged() }
        }
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            model?.pageChanged(); model?.loading = true; model?.browserError = nil
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { update(webView); model?.loading = false }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error, web: webView) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error, web: webView) }
        private func failed(_ error: Error, web: WKWebView) {
            if (error as NSError).code == NSURLErrorCancelled { return }
            update(web); model?.loading = false; model?.pause()
            model?.browserError = "This website couldn’t load. Check the address or connection and retry. Some websites don’t allow embedded browsers."
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { model?.pause(); model?.loading = false; model?.browserError = "The browser was interrupted. Reload the page to continue." }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url, (try? WorksModel.website(url.absoluteString)) != nil else {
                decisionHandler(.cancel)
                if navigationAction.targetFrame?.isMainFrame != false { model?.browserError = "This link needs another app or a supported HTTPS website. Use the website directly if required." }
                return
            }
            decisionHandler(.allow)
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url, (try? WorksModel.website(url.absoluteString)) != nil {
                model?.takeControl(); webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
