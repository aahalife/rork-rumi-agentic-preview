import Foundation
import Testing
@testable import Nudge

@MainActor
struct PortalIntegrationTests {
    @Test func portalOriginRefusesExternalAPIsAndEncodedPaths() {
        let origin = HostedEndpoints.portal
        #expect(PortalOrigin.allows(origin.appending(path: "portal/results"), origin: origin))
        #expect(!PortalOrigin.allows(origin.appending(path: "portal/api/results"), origin: origin))
        #expect(!PortalOrigin.allows(URL(string: "https://evil.example/portal/results")!, origin: origin))
        #expect(!PortalOrigin.allows(URL(string: origin.absoluteString + "/portal/%61pi/results")!, origin: origin))
        #expect(!PortalOrigin.allows(URL(string: origin.absoluteString + "/portal/../~api/demo/native-access")!, origin: origin))
        #expect(PortalOrigin.allowsNavigation(origin.appending(path: "~api/demo/native-access"), origin: origin))
        #expect(!PortalOrigin.allows(origin.appending(path: "~api/demo/native-access"), origin: origin))
    }

    @Test func accessRetryIsReadOnlyAndRejectsUnauthorized() async throws {
        var checks: Int = 0
        let accepted = try await PrivateAccessConnection.validate(key: " fictional ", status: { code in
            #expect(code == "fictional")
            checks += 1
            return checks == 1 ? 503 : 200
        }, pause: { _ in })
        #expect(accepted == "fictional")
        #expect(checks == 2)
        var rejectedChecks: Int = 0
        do {
            _ = try await PrivateAccessConnection.validate(key: "fictional", status: { _ in rejectedChecks += 1; return 403 }, pause: { _ in })
            Issue.record("Unauthorized access should be rejected")
        } catch {
            #expect(rejectedChecks == 1)
        }
    }

    @Test func consequentialControlsRequireApprovalWithoutModelFlag() {
        let submit = Element(ref: 1, role: "button", name: "Continue", tag: "button", type: "submit")
        let send = Element(ref: 2, role: "button", name: "Send message", tag: "button", type: "button")
        let read = Element(ref: 3, role: "link", name: "View result", tag: "a")
        #expect(PortalActionPolicy.needsApproval(element: submit, args: [:]))
        #expect(PortalActionPolicy.needsApproval(element: send, args: ["consequential": .bool(false)]))
        #expect(!PortalActionPolicy.needsApproval(element: read, args: [:]))
        #expect(PortalActionPolicy.needsApproval(element: nil, args: [:]))
    }

    @Test func stoppedSessionDoesNotAcceptRequestsOrApprovals() {
        let browser = BrowserModel()
        let bridge = AgentBridge(backendOrigin: HostedEndpoints.portal, browser: browser)
        let session = AgentSession(backendURL: HostedEndpoints.backend, demoKey: "fictional", bridge: bridge)
        session.stop()
        session.sendUserMessage("Book a visit")
        session.respondToConfirm(allowed: true)
        #expect(session.state == .disconnected)
        #expect(session.messages.isEmpty)
        #expect(session.pendingConfirm == nil)
        #expect(!session.isRunning)
    }
}
