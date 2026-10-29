import SwiftUI

struct RumiAppAPIView: View {
    @State private var api = RumiAppAPI.shared
    @State private var base = RumiAppAPI.shared.settings?.baseURL ?? ""
    @State private var appID = RumiAppAPI.shared.settings?.appID ?? ""
    @State private var phone = ""
    @State private var code = ""
    @State private var challenge: RumiAPIChallenge?
    @State private var configuration: RumiAPIConfig?
    @State private var memory: RumiAPIMemory?
    @State private var goal = ""
    @State private var review: GoalReview?
    @State private var busy = false
    @State private var notice: String?
    @State private var error: String?
    @State private var uncertain = false
    @State private var task: Task<Void, Never>?
    private struct GoalReview: Identifiable { let id = UUID(); let text: String; let identity: UUID }
    var body: some View {
        Form {
            Section {
                Text("Connect to the existing Rumi service").font(.title2.bold())
                Text("This is separate from the local demo and legacy Companion connection. The public app ID identifies the integration; a verified user session is still required to read personal data. No new backend is created.").font(.callout)
            }
            Section("Confirmed integration settings") {
                TextField("HTTPS API base URL", text: $base).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Public app ID", text: $appID).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Check service & save settings") {
                    run {
                        challenge = nil; configuration = nil; memory = nil
                        try api.configure(RumiAPISettings(baseURL: base.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/")), appID: appID.trimmingCharacters(in: .whitespacesAndNewlines)))
                        _ = try await api.health()
                        configuration = try await api.config()
                        notice = "The health and app configuration endpoints responded. This does not verify login or personal records."
                    }
                }.disabled(busy || base.isEmpty || appID.isEmpty)
                if let configuration {
                    LabeledContent("API version", value: configuration.api_version ?? "Not returned")
                    LabeledContent("Records mode", value: configuration.records_mode ?? "Not returned")
                }
                Text("The default base URL and public app ID are owner-confirmed. Saved custom settings are preserved. Do not paste an ElevenLabs, Supabase, Photon or server key here. Changing these settings disconnects this API session.").font(.footnote)
            }
            if !api.authenticated {
                Section("Verify your existing Rumi account") {
                    TextField("+1 phone number", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
                    Button("Request code in Rumi iMessage") { run { challenge = try await api.challenge(phone: phone); notice = "Read the challenge status below. No code is returned to this app." } }.disabled(busy || api.settings == nil || phone.isEmpty)
                    if let challenge {
                        Text("Status: \(challenge.status.replacingOccurrences(of: "_", with: " "))")
                        if challenge.status == "imessage_connection_needed" {
                            Text("Send Hi to your existing Rumi messaging thread, then start a new challenge. Requesting a challenge does not establish ownership.")
                            if let number = challenge.messaging_number { Text("Rumi messaging number: \(number)").textSelection(.enabled) }
                        }
                        if let seconds = challenge.expires_in { Text("Expiry window returned by service: \(seconds) seconds. Resending does not extend the original expiry.").font(.footnote) }
                        TextField("Six-digit code", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode).privacySensitive()
                        Button("Verify code") { run { try await api.verify(challenge, code: code); code = ""; phone = ""; self.challenge = nil; notice = "Rumi verified the session. Your token is stored only in this device’s Keychain." } }.disabled(busy || code.count != 6)
                        Button("Resend code") { run { self.challenge = try await api.resend(challenge) } }.disabled(busy)
                    }
                }
            } else {
                Section("Verified account · Shared Rumi context") {
                    Button("Refresh saved memory") { run { memory = try await api.memory() } }.disabled(busy)
                    if let memory {
                        LabeledContent("Memory permission", value: memory.memory_consent ?? "Not returned")
                        ForEach(memory.items ?? []) { item in
                            VStack(alignment: .leading) { Text(item.body?.text ?? "Saved item"); Text([item.kind, item.status].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
                        }
                        if memory.memory_consent == "granted" {
                            TextField("A goal you choose", text: $goal, axis: .vertical).lineLimit(2...5)
                            Button("Review exact goal") { review = GoalReview(text: goal.trimmingCharacters(in: .whitespacesAndNewlines), identity: api.identity) }.disabled(busy || uncertain || goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || goal.count > 2000)
                        }
                    }
                    Text("Permission is managed by the existing Rumi service. Memory consent is not permission to call, book, send or change medicines.").font(.footnote)
                }
                Section("Inspect existing service data · Read only") {
                    ForEach(RumiAppAPI.Resource.allCases) { resource in NavigationLink(resource.rawValue.replacingOccurrences(of: "-", with: " ").capitalized) { RumiAPIResourceView(resource: resource) } }
                    Text("Records retain the service’s test/live mode and sources. No clinical charts are inferred from the loosely specified records payload. ElevenLabs session playback and write actions other than reviewed goal saving are not connected in this adapter yet.").font(.footnote)
                }
                Section {
                    Button("Sign out through Rumi", role: .destructive) { run { try await api.logout(); clearPrivateState() } }.disabled(busy)
                    Button("Remove session from this device", role: .destructive) { task?.cancel(); api.disconnect(); clearPrivateState(); notice = "Device credentials removed. This did not revoke remote sessions or pause calls." }
                }
            }
            if busy { Section { ProgressView("Contacting existing Rumi service…") } }
            if let notice { Section { Text(notice).font(.callout) } }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            if uncertain { Section { Text("The save was not confirmed. It may have reached Rumi. Check saved goals before doing anything else; do not create a new submission to retry an uncertain write."); Button("I have checked the saved goals") { uncertain = false }.disabled(busy) } }
        }.navigationTitle("Rumi App API")
            .sheet(item: $review) { item in
                NavigationStack {
                    Form {
                        Section("Save this exact goal to real Rumi?") { Text(item.text); Text("This is a real shared-memory save, not a demo receipt.").font(.footnote) }
                        Button("Confirm save to Rumi") {
                            review = nil
                            run {
                                guard api.identity == item.identity else { throw CompanionError(message: "The account changed. Review the goal again.") }
                                uncertain = true
                                let receipt = try await api.saveGoal(item.text, id: item.id.uuidString)
                                guard receipt.confirmed else { throw CompanionError(message: "Rumi did not confirm that this goal was committed. Inspect the saved goals before retrying.") }
                                uncertain = false; goal = ""; notice = "Rumi explicitly confirmed the goal save."
                                memory = try await api.memory()
                            }
                        }.disabled(api.identity != item.identity || busy)
                    }.navigationTitle("Review goal").toolbar { Button("Cancel") { review = nil } }
                }
            }
            .onChange(of: api.identity) { _, _ in clearPrivateState() }
            .onDisappear { task?.cancel(); task = nil }
    }
    private func clearPrivateState() { memory = nil; challenge = nil; code = ""; phone = ""; goal = ""; review = nil; notice = nil; error = nil; uncertain = false }
    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true; error = nil; notice = nil
        task = Task { @MainActor in
            defer { busy = false }
            do { try await operation() } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
        }
    }
}

private struct RumiAPIResourceView: View {
    let resource: RumiAppAPI.Resource
    @State private var result: RumiJSON?
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Read-only service response").font(.headline)
                Text("This view preserves the API payload and its mode/source fields. It does not interpret, rewrite or combine it with demo profiles.").font(.footnote)
                if let result { Text(result.formatted).font(.system(.callout, design: .monospaced)).textSelection(.enabled).privacySensitive() }
                else if let error { Text(error).foregroundStyle(.red) }
                else { ProgressView("Reading…") }
            }.padding(20)
        }.navigationTitle(resource.rawValue.capitalized)
            .task {
                do { result = try await RumiAppAPI.shared.read(resource) } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
            }
            .onChange(of: RumiAppAPI.shared.identity) { _, _ in result = nil; error = "The account changed. Reopen this screen." }
            .onDisappear { result = nil }
    }
}
