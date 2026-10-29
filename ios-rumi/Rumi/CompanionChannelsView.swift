import SwiftUI

struct CompanionCall: Decodable, Identifiable {
    let id: String
    let number: String
    let at: Double
    let status: String
    var date: Date { Date(timeIntervalSince1970: at / 1000) }
    var statusLabel: String {
        switch status {
        case "scheduled": "Scheduled"
        case "submitted": "Submitted to calling service"
        case "connecting": "Connecting — check before retrying"
        case "unknown": "Outcome unknown — check before retrying"
        case "failed": "Not accepted by calling service"
        case "cancelled": "Cancelled"
        default: status
        }
    }
}
struct CompanionChannelsView: View {
    @Environment(\.openURL) private var openURL
    @State private var number = ""
    @State private var schedule = false
    @State private var date = Date().addingTimeInterval(3600)
    @State private var calls: [CompanionCall] = []
    @State private var review: CallReview?
    @State private var link: MessageLink?
    @State private var error: String?
    @State private var busy = false
    @State private var confirmUnlink = false
    @State private var serviceStatus: CompanionStatus?
    struct CallReview: Identifiable { let id = UUID(); let number: String; let at: Date; let immediate: Bool }
    struct MessageLink: Decodable { let code: String; let address: String; let expiresIn: Int }
    struct Calls: Decodable { let calls: [CompanionCall] }
    var body: some View {
        Form {
            if serviceStatus?.sharedBackend != true {
            Section {
                TextField("US number, e.g. +1 415 555 0123", text: $number).keyboardType(.phonePad).textContentType(.telephoneNumber)
                Toggle("Choose a time", isOn: $schedule)
                if schedule { DatePicker("Call at", selection: $date, in: Date()...Date().addingTimeInterval(30 * 86400)) }
                Button("Review call") {
                    let digits = number.filter(\.isNumber)
                    let normalized = "+" + (digits.count == 10 ? "1" + digits : digits)
                    guard normalized.range(of: "^\\+1[2-9]\\d{2}[2-9]\\d{6}$", options: .regularExpression) != nil else { error = "Enter a valid US phone number."; return }
                    error = nil; review = CallReview(number: normalized, at: schedule ? date : Date(), immediate: !schedule)
                }.disabled(busy)
            } header: { Text("Call me") } footer: { Text("Rumi’s AI agent will call the number you approve. Only request calls to a number you own or have permission to contact. Carrier charges may apply.") }
            if !calls.isEmpty {
                Section("Recent calls") {
                    ForEach(calls) { call in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(call.number).font(.headline)
                            Text(call.date, style: .date) + Text(" · ") + Text(call.date, style: .time)
                            Text(call.statusLabel).font(.caption).foregroundStyle(.secondary)
                            if call.status == "scheduled" { Button("Cancel call", role: .destructive) { cancel(call) }.disabled(busy) }
                        }.padding(.vertical, 5)
                    }
                }
            }
            }
            if serviceStatus?.sharedBackend == true {
                Section("Shared Rumi conversation") {
                    Text(serviceStatus?.historyNotice ?? "Your existing Rumi backend owns messaging and calls.").font(.footnote)
                    NavigationLink("Saved context & call permissions") { SharedContextView() }
                    Text("Continue in your existing Rumi iMessage thread. App-side relinking and one-off calls are disabled to avoid a second messaging or call owner.").font(.footnote).foregroundStyle(.secondary)
                }
            } else if serviceStatus?.conversationService == "Existing Rumi API" {
                Section("Existing Rumi conversation") {
                    Text(serviceStatus?.historyNotice ?? "Your existing Rumi service owns messaging.").font(.footnote)
                    Text("Calls can only ring your verified Rumi number. App unlinking does not disconnect your existing messaging service.").font(.footnote).foregroundStyle(.secondary)
                }
            } else {
            Section {
                Button("Create a secure linking code") {
                    busy = true; error = nil
                    Task {
                        do { link = try await CompanionConnection.shared.request("imessage/link", body: [:]) }
                        catch { self.error = error.localizedDescription }
                        busy = false
                    }
                }.disabled(busy)
                if let link {
                    Text("Send the linking message to \(link.address) within 10 minutes. Once linked, conversation text is shared between this app and your iMessage conversation.").font(.footnote)
                    Button("Open linking message in Messages") {
                        var components = URLComponents(); components.scheme = "sms"; components.path = link.address
                        components.queryItems = [URLQueryItem(name: "body", value: "Link Rumi \(link.code)")]
                        if let url = components.url { openURL(url) }
                    }
                }
                Button("Unlink iMessage", role: .destructive) { confirmUnlink = true }.disabled(busy)
            } header: { Text("Rumi in iMessage") } footer: { Text("Powered by your Photon v2 connection. Linking verifies the sender before sharing conversation context. Reply STOP in iMessage to unlink. This is not an emergency channel.") }
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
        }
        .navigationTitle("Calls & iMessage")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Refresh") { Task { await refresh() } }.disabled(busy) } }
        .task { await refresh() }
        .sheet(item: $review) { proposal in
            NavigationStack {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Approve this call").font(.rumiTitle2.weight(.semibold))
                    LabeledContent("To", value: proposal.number)
                    LabeledContent("When", value: proposal.immediate ? "Now" : proposal.at.formatted(date: .abbreviated, time: .shortened))
                    Text("I have permission to receive an AI-agent call at this number. This approval applies only to this number and time.")
                    Button(busy ? "Submitting…" : "Approve & \(proposal.immediate ? "call" : "schedule")") { submit(proposal) }.buttonStyle(.borderedProminent).disabled(busy)
                    Button("Cancel", role: .cancel) { review = nil }.disabled(busy)
                    if let error { Text(error).foregroundStyle(.red) }
                    Spacer()
                }.padding(24).navigationTitle("Review").navigationBarTitleDisplayMode(.inline)
            }.presentationDetents([.medium, .large]).interactiveDismissDisabled(busy)
        }
        .confirmationDialog("Unlink your iMessage conversations?", isPresented: $confirmUnlink, titleVisibility: .visible) {
            Button("Unlink", role: .destructive) {
                Task {
                    do { let _: ServiceOK = try await CompanionConnection.shared.request("imessage/unlink", body: [:]); link = nil }
                    catch { self.error = error.localizedDescription }
                }
            }
        }
    }
    private func refresh() async {
        do {
            serviceStatus = try await CompanionConnection.shared.request("status")
            let response: Calls = try await CompanionConnection.shared.request("calls"); calls = response.calls
        }
        catch { self.error = error.localizedDescription }
    }
    private func submit(_ proposal: CallReview) {
        busy = true; error = nil
        Task {
            do {
                let _: CompanionCall = try await CompanionConnection.shared.request("calls/create", body: ["id": proposal.id.uuidString, "number": proposal.number, "at": (proposal.immediate ? Date() : proposal.at).timeIntervalSince1970 * 1000, "consent": true])
                review = nil; await refresh()
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    private func cancel(_ call: CompanionCall) {
        busy = true
        Task {
            do { let _: CompanionCall = try await CompanionConnection.shared.request("calls/cancel", body: ["id": call.id]); await refresh() }
            catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}
