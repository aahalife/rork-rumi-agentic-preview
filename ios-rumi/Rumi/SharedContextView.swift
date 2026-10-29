import SwiftUI

private struct SharedRumiContext: Decodable {
    struct Item: Decodable, Identifiable {
        struct Body: Decodable { let text: String? }
        let id: String
        let kind: String
        let body: Body
        let status: String
    }
    struct Schedule: Decodable {
        let time: String?
        let timezone: String?
        let paused: Bool?
    }
    let status: String
    let memoryConsent: String?
    let items: [Item]
    let schedule: Schedule?
}
private struct SharedRumiReceipt: Decodable {
    let status: String
    let committed: Bool?
}

struct SharedContextView: View {
    @State private var context: SharedRumiContext?
    @State private var goal = ""
    @State private var reviewedGoal: String?
    @State private var confirmPermission = false
    @State private var confirmWithdrawal = false
    @State private var confirmPause = false
    @State private var busy = false
    @State private var needsReconciliation = false
    @State private var notice: String?
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                Text("These choices belong to your verified Rumi profile across this app, linked iMessage and phone. Saved context is not a combined transcript or a medical record.").font(.footnote).foregroundStyle(.secondary)
            }
            if let context, context.status == "ok" {
                Section {
                    LabeledContent("Remembering", value: context.memoryConsent == "granted" ? "Allowed" : "Not allowed")
                    if context.memoryConsent == "granted" {
                        Button("Stop remembering", role: .destructive) { confirmWithdrawal = true }.disabled(busy || needsReconciliation)
                    } else {
                        Button("Allow shared memory") { confirmPermission = true }.disabled(busy || needsReconciliation)
                    }
                } header: { Text("Memory permission") } footer: {
                    Text("Permission to remember is separate from permission to call. Stopping memory does not erase previous saved items. Rumi’s existing service controls retention and deletion.")
                }
                Section("Saved goals & actions") {
                    let items = context.items.filter { ["goal", "action", "progress", "visit_question"].contains($0.kind) }
                    if items.isEmpty { Text("No saved goals or actions were returned.").foregroundStyle(.secondary) }
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.body.text ?? "Saved item")
                            Text("\(label(item.kind)) · \(item.status)").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 3)
                    }
                    if context.memoryConsent == "granted" {
                        TextField("A goal you choose", text: $goal, axis: .vertical).lineLimit(2...5)
                        Button("Review goal") { reviewedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .disabled(busy || needsReconciliation || goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || goal.count > 2000)
                    }
                }
                Section {
                    if let schedule = context.schedule {
                        LabeledContent("Recurring calls", value: schedule.paused == true ? "Paused" : "Active")
                        if let time = schedule.time { LabeledContent("Preferred time", value: time) }
                        if let timezone = schedule.timezone { LabeledContent("Time zone", value: timezone) }
                    } else { Text("No recurring call schedule was returned.").foregroundStyle(.secondary) }
                    Button("Pause Rumi’s recurring calls", role: .destructive) { confirmPause = true }.disabled(busy || needsReconciliation)
                } header: { Text("Call permission") } footer: { Text("The existing Rumi scheduler owns these calls. Pausing does not hang up a call already in progress or cancel a one-off call scheduled in an older app mode.") }
            } else if busy {
                Section { ProgressView("Reading saved context…") }
            } else if context != nil {
                Section { Text("Saved context is unavailable. Refresh or reconnect your verified Rumi account.").foregroundStyle(.secondary) }
            }
            if let notice { Section { Text(notice).foregroundStyle(Color.brandPrimary) } }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            if needsReconciliation { Section { Text("The change was not confirmed. Refresh before doing anything else; it may already have reached Rumi.").font(.footnote) } }
        }
        .navigationTitle("Saved context")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Refresh") { Task { await refresh() } }.disabled(busy) } }
        .task { await refresh() }
        .onChange(of: CompanionConnection.shared.identityVersion) { _, _ in context = nil; goal = ""; notice = nil; error = nil }
        .confirmationDialog("Allow Rumi to remember across linked conversations?", isPresented: $confirmPermission, titleVisibility: .visible) {
            Button("Allow shared memory") { change(["operation": "set_consent", "permission": "granted"]) }
        } message: { Text("Rumi may use saved context in this app, linked iMessage and phone. This does not give permission to call you.") }
        .confirmationDialog("Stop remembering across linked conversations?", isPresented: $confirmWithdrawal, titleVisibility: .visible) {
            Button("Stop remembering", role: .destructive) { change(["operation": "set_consent", "permission": "withdrawn"]) }
        }
        .confirmationDialog("Pause Rumi’s recurring calls?", isPresented: $confirmPause, titleVisibility: .visible) {
            Button("Pause recurring calls", role: .destructive) { change(["operation": "pause_calls"]) }
        }
        .sheet(isPresented: Binding(get: { reviewedGoal != nil }, set: { if !$0 { reviewedGoal = nil } })) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Save this exact goal?").font(.rumiTitle2)
                    Text(reviewedGoal ?? "").font(.rumiBody)
                    Text("It will become a saved goal in your shared Rumi profile, not a verified clinical fact.").font(.footnote).foregroundStyle(.secondary)
                    Button("Save goal") {
                        guard let text = reviewedGoal else { return }
                        reviewedGoal = nil
                        change(["operation": "save_goal", "text": text, "confirmed": true])
                    }.buttonStyle(.borderedProminent)
                    Button("Cancel", role: .cancel) { reviewedGoal = nil }
                    Spacer()
                }.padding(24).navigationTitle("Review").navigationBarTitleDisplayMode(.inline)
            }.presentationDetents([.medium, .large])
        }
    }
    private func label(_ kind: String) -> String {
        switch kind { case "goal": "Goal"; case "action": "Action"; case "progress": "Reported progress"; default: "Visit question" }
    }
    private func refresh() async {
        busy = true; error = nil
        defer { busy = false }
        do {
            context = try await CompanionConnection.shared.request("context")
            needsReconciliation = false
        } catch { self.error = error.localizedDescription }
    }
    private func change(_ values: [String: Any]) {
        busy = true; error = nil; notice = nil
        var payload = values; payload["id"] = UUID().uuidString
        Task {
            defer { busy = false }
            do {
                let receipt: SharedRumiReceipt = try await CompanionConnection.shared.request("memory", body: payload)
                guard receipt.status == "ok", receipt.committed == true else {
                    needsReconciliation = true
                    error = "Rumi did not confirm this change (\(receipt.status.replacingOccurrences(of: "_", with: " "))). Refresh saved context before trying again."
                    return
                }
                notice = "Saved by your shared Rumi backend."
                if values["operation"] as? String == "save_goal" { goal = "" }
                await refresh()
            } catch { needsReconciliation = true; self.error = error.localizedDescription }
        }
    }
}
