import SwiftUI

/// The repository-backed browser workspace. Its hosted patients are not imported into AppModel.
struct PortalWorkspaceView: View {
    @Environment(AppModel.self) private var app
    @State private var accessCode: String = ""
    @State private var requestText: String = ""
    @State private var isConnecting: Bool = false
    @State private var notice: String?
    @State private var showsApproval: Bool = false
    @State private var connectionTask: Task<Void, Never>?
    private var companion: CompanionModel { app.portalCompanion }

    var body: some View {
        Group {
            if let session = companion.session {
                GeometryReader { geometry in
                    connectedWorkspace(session, browserHeight: geometry.size.height * 0.43)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Your portal, with Rumi").font(NudgeType.serif(28))
                        Text("AmalgamRx sample portal · Priya / James\nSeparate from \(app.persona.firstName)’s profile. Changes are saved in a shared fictional workspace, never a live provider account.")
                            .font(NudgeType.rounded(13)).foregroundStyle(Theme.inkMuted)
                        connectionForm
                    }.padding(.horizontal, 20).padding(.vertical, 20)
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .background { BrandAtmosphereView() }
        .onChange(of: companion.session?.pendingConfirm?.id, initial: true) { _, id in showsApproval = id != nil }
        .sheet(isPresented: $showsApproval) {
            if let session = companion.session, let pending = session.pendingConfirm {
                ApprovalReviewView(
                    proposal: pending.summary,
                    disclosure: "Fictional hosted workspace. Only this page and form; if either changes, Rumi must ask again.",
                    approve: { if session.pendingConfirm?.id == pending.id { session.respondToConfirm(allowed: true) } },
                    decline: { if session.pendingConfirm?.id == pending.id { session.respondToConfirm(allowed: false) } }
                )
                .presentationDetents([.large])
                .presentationBackground(Theme.base)
                .accessibilityIdentifier("portal.approval")
            }
        }
        .onDisappear {
            connectionTask?.cancel()
            connectionTask = nil
            isConnecting = false
        }
    }

    private var connectionForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Private portal access", systemImage: "lock.shield").font(NudgeType.serif(22))
            Text("Use the invitation code for your existing browser-agent service. It is saved in this phone’s Keychain, not shared with Rumi’s model.")
                .font(NudgeType.rounded(14)).foregroundStyle(Theme.inkMuted)
            SecureField("Invitation code", text: $accessCode)
                .textContentType(.none).textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(14).background(Theme.surface, in: .rect(cornerRadius: 14))
                .accessibilityIdentifier("portal.accessCode")
            Button(isConnecting ? "Connecting…" : "Connect securely") {
                isConnecting = true
                notice = nil
                connectionTask = Task {
                    do {
                        try await companion.connect(address: companion.savedAddress, key: accessCode)
                        accessCode = ""
                        companion.session?.start()
                    } catch is CancellationError { }
                    catch { notice = error.localizedDescription }
                    isConnecting = false
                    connectionTask = nil
                }
            }
            .buttonStyle(.borderedProminent).tint(Theme.brandForest)
            .frame(minHeight: 44).disabled(isConnecting || accessCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if let notice { Text(notice).font(NudgeType.rounded(14)).foregroundStyle(Theme.inkMuted) }
            Text("Portal content and your requests are processed by the existing hosted agent service. Use fictional information only. No Epic integration, records import, rides or payments.")
                .font(NudgeType.rounded(12)).foregroundStyle(Theme.inkMuted)
        }
        .padding(18).frostedSurface(radius: 26)
    }

    private func connectedWorkspace(_ session: AgentSession, browserHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AmalgamRx · Priya / James · fictional hosted workspace, separate from \(app.persona.firstName)")
                .font(NudgeType.rounded(11)).foregroundStyle(Theme.inkMuted)
            Label(session.statusLabel, systemImage: session.pendingConfirm == nil ? "sparkles" : "hand.raised")
                .font(NudgeType.rounded(16, .semibold)).accessibilityIdentifier("portal.status")
            if let note = session.connectionNote { Text(note).font(NudgeType.rounded(14)).foregroundStyle(Theme.inkMuted) }
            if session.state == .disconnected {
                Button("Connect agent") { session.start() }
                    .buttonStyle(.borderedProminent).tint(Theme.brandForest).frame(minHeight: 44)
            }
            preview(session, height: browserHeight)
            if session.pendingConfirm != nil {
                Button("Your approval is needed · review proposal") { showsApproval = true }
                    .font(NudgeType.rounded(14, .semibold)).frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.brandSun.opacity(0.35), in: .capsule)
            }
            ScrollView {
            VStack(alignment: .leading, spacing: 14) {
            if session.messages.isEmpty {
                Text("Sign in yourself in the portal below: demo / demo123 for Priya, or demo2 / demo123 for James. These are fixed fictional accounts. Never type real passwords into this showcase.")
                    .font(NudgeType.rounded(13)).foregroundStyle(Theme.inkMuted)
            }
            Text("Rumi · working with you").font(NudgeType.rounded(14, .semibold)).padding(.top, 8)
            ScrollView {
            VStack(alignment: .leading, spacing: 12) {
            ForEach(session.messages) { message in
                VStack(alignment: .leading, spacing: 5) {
                    Text(message.role == .patient ? "You" : "Rumi").font(NudgeType.rounded(12, .semibold))
                    Text(message.text).font(NudgeType.rounded(15)).textSelection(.enabled)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).frostedSurface(radius: 20)
            }
            }
            }.frame(maxHeight: 240)
            if session.state != .disconnected {
                TextField("Ask about this portal", text: $requestText, axis: .vertical)
                    .lineLimit(1...4).padding(14).background(Theme.surface, in: .rect(cornerRadius: 14))
                    .disabled(session.isRunning).accessibilityIdentifier("portal.request")
                HStack {
                    Button("Ask Rumi") { session.sendUserMessage(requestText); requestText = "" }
                        .buttonStyle(.borderedProminent).tint(Theme.brandForest)
                        .disabled(session.isRunning || requestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || requestText.count > 4000)
                    Button("Stop") { session.stop() }.buttonStyle(.bordered)
                }.frame(minHeight: 48)
                if session.messages.isEmpty {
                    Button("When is my next appointment?") { session.sendUserMessage("When is my next appointment?") }
                        .buttonStyle(.bordered).frame(minHeight: 44).disabled(session.isRunning)
                }
            }
            Button("Remove portal access", role: .destructive) {
                session.disconnect()
                connectionTask = Task { await companion.removeDemoAccess(); connectionTask = nil }
            }.frame(minHeight: 44)
            if let note = DeviceSignIn.shared.storageNotice { Text(note).font(NudgeType.rounded(13)) }
            }
            }
        }
    }

    private func preview(_ session: AgentSession, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Button {
                companion.isCollapsed.toggle()
            } label: {
                HStack {
                    Label("Browser preview", systemImage: "globe")
                    Spacer()
                    Text(companion.isCollapsed ? "Expand" : "Collapse")
                }.font(NudgeType.rounded(14, .semibold)).padding(16).frame(minHeight: 52)
            }
            .accessibilityLabel(companion.isCollapsed ? "Expand portal browser" : "Collapse portal browser")
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                VStack(alignment: .leading, spacing: 2) {
                    Text(companion.browser.host.isEmpty ? companion.portalURL.host() ?? "Hosted portal" : companion.browser.host).lineLimit(1)
                    Text(companion.browser.title).foregroundStyle(Theme.inkMuted).lineLimit(1)
                }
                Spacer()
                Button { session.stop(); companion.browser.reload() } label: { Image(systemName: "arrow.clockwise").frame(width: 44, height: 44) }
                    .accessibilityLabel("Stop and reload page")
            }.font(NudgeType.rounded(11)).padding(.horizontal, 12)
            // Keep the actual WebView mounted when collapsed so login/forms and approval bindings survive.
            BrowserView(model: companion.browser, startURL: companion.portalURL.appending(path: "portal/home"))
                .frame(height: companion.isCollapsed ? 0 : height)
                .clipped().accessibilityHidden(companion.isCollapsed)
                .allowsHitTesting(!companion.isCollapsed && !session.isRunning)
            if companion.browser.isLoading && !companion.isCollapsed { ProgressView().padding(10) }
            if let error = companion.browser.loadError {
                Text(error).font(NudgeType.rounded(13)).padding(12)
                Button("Try again") { session.stop(); companion.browser.reload() }.frame(minHeight: 44)
            }
        }
        .clipShape(.rect(cornerRadius: 24)).frostedSurface(radius: 24)
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(session.isRunning && session.pendingConfirm == nil ? Theme.brandMint : session.pendingConfirm != nil ? Theme.brandSun : .clear, lineWidth: 2).allowsHitTesting(false))
        .shadow(color: session.isRunning ? Theme.brandMint.opacity(0.4) : .clear, radius: 18)
    }
}
