import SwiftUI

/// Browser-assisted tasks in an isolated sample workspace; never accepts real credentials.
struct BrowserDemoView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var requestText: String = ""
    @State private var showsApproval: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var demo: BrowserDemoModel { model.browserDemo }

    var body: some View {
        NavigationStack {
            Group {
                if model.useHostedPortal {
                    PortalWorkspaceView()
                } else {
                    sampleWorkspace
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Minimize") { dismiss() } }
                if model.useHostedPortal {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") {
                            model.portalCompanion.session?.stop()
                            model.useHostedPortal = false
                        }
                    }
                }
            }
        }
        .onChange(of: demo.phase, initial: true) { _, phase in showsApproval = phase == .review && !model.useHostedPortal }
        .onChange(of: demo.reviewText) { _, _ in if demo.phase == .review && !model.useHostedPortal { showsApproval = true } }
        .sheet(isPresented: $showsApproval) {
            if demo.phase == .review, let scenario = demo.scenario {
                ApprovalReviewView(
                    proposal: demo.reviewText,
                    disclosure: "Sample task · no real booking, payment or external delivery.",
                    approve: { demo.approve() }, decline: { demo.stop() },
                    changeProposal: scenario == .ride ? { demo.changeFare() } : nil
                )
                .presentationDetents([.large])
                .presentationBackground(Theme.base)
                .accessibilityIdentifier("browserDemo.approval")
            }
        }
    }

    private var sampleWorkspace: some View {
            ZStack {
                BrandAtmosphereView()
                if let scenario = demo.scenario {
                    GeometryReader { geometry in
                        task(scenario, browserHeight: geometry.size.height * 0.43)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                    }
                } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 12) {
                            BrandGlyph(systemName: "sparkles", tint: Theme.brandMint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Rumi’s work").font(NudgeType.serif(30)).foregroundStyle(Theme.ink)
                                Text("A little less to carry.").font(NudgeType.rounded(15)).foregroundStyle(Theme.inkMuted)
                            }
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "person.crop.circle").font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(model.persona.firstName)’s sample workspace").font(NudgeType.rounded(14, .semibold))
                                Text("Autonomous site mockups; approval for consequential actions only. No live accounts, messages or payments.")
                                    .font(NudgeType.rounded(12))
                            }
                        }
                        .foregroundStyle(Theme.inkMuted).padding(14).frostedSurface(radius: 18)
                        if demo.scenario == nil {
                            Button { model.useHostedPortal = true } label: {
                                HStack(spacing: 14) {
                                    BrandGlyph(systemName: "globe", tint: Theme.brandMint)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Open browser workspace").font(NudgeType.serif(20))
                                        Text("Use your hosted portal agent").font(NudgeType.rounded(13)).foregroundStyle(Theme.inkMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .foregroundStyle(Theme.ink).padding(18).frostedSurface(radius: 26)
                            }.buttonStyle(NudgeButtonStyle())
                        }
                        if let scenario = demo.scenario {
                            task(scenario)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(BrowserDemoModel.Scenario.allCases) { scenario in
                                    Button { start(scenario) } label: {
                                        HStack(spacing: 14) {
                                            BrandGlyph(systemName: glyph(scenario), tint: scenario == .labs ? Theme.sky : Theme.brandMint)
                                            Text(scenario.title).font(NudgeType.serif(20))
                                            Spacer(minLength: 0)
                                            Image(systemName: "arrow.up.right").font(.system(size: 18))
                                        }
                                        .foregroundStyle(Theme.ink).padding(18).frame(minHeight: 80)
                                        .frostedSurface(radius: 26)
                                    }
                                    .buttonStyle(NudgeButtonStyle())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 20)
                }
                }
            }
    }

    private func task(_ scenario: BrowserDemoModel.Scenario, browserHeight: CGFloat = 340) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(scenario.title).font(NudgeType.serif(23)).foregroundStyle(Theme.ink)
            Text("\(model.persona.firstName)’s sample workspace · site mockups, no live accounts or payments")
                .font(NudgeType.rounded(11)).foregroundStyle(Theme.inkMuted)
            HStack(spacing: 8) {
                Circle().fill(demo.phase == .review ? Theme.attention : Theme.brandMint).frame(width: 7, height: 7)
                Text(demo.statusLabel).font(NudgeType.rounded(14, .semibold))
            }
            .foregroundStyle(Theme.brandForest).accessibilityIdentifier("browserDemo.status")
            VStack(alignment: .leading, spacing: 0) {
                Button { demo.isCollapsed.toggle() } label: {
                    HStack {
                        Label("Browser preview", systemImage: "globe")
                        Spacer()
                        Text(demo.isCollapsed ? "Expand" : "Collapse")
                    }
                    .font(NudgeType.rounded(14, .semibold)).foregroundStyle(Theme.ink)
                    .padding(16).frame(minHeight: 52)
                }
                .buttonStyle(NudgeButtonStyle())
                .accessibilityLabel(demo.isCollapsed ? "Expand browser preview" : "Collapse browser preview")
                if !demo.isCollapsed {
                    ScrollViewReader { proxy in
                        ScrollView { SampleSitePreviewView(demo: demo, scenario: scenario) }
                            .onChange(of: demo.step) { _, step in
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) { proxy.scrollTo(step, anchor: .center) }
                            }
                            .onChange(of: demo.phase) { _, phase in
                                if phase == .browsing { proxy.scrollTo(demo.step, anchor: .center) }
                            }
                    }.frame(height: demo.phase == .review ? min(browserHeight, 130) : browserHeight)
                }
            }
            .clipShape(.rect(cornerRadius: 26)).frostedSurface(radius: 26)
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(demo.phase == .browsing ? Theme.brandMint : .clear, lineWidth: 2).allowsHitTesting(false))
            .shadow(color: demo.phase == .browsing ? Theme.brandMint.opacity(0.35) : .clear, radius: 16)
            if demo.phase == .review {
                control("Your approval is needed · review proposal") { showsApproval = true }
                    .background(Theme.brandSun.opacity(0.35), in: .capsule)
                    .accessibilityIdentifier("browserDemo.reviewReminder")
            }
            ScrollView {
            VStack(alignment: .leading, spacing: 14) {
            conversation
            if model.activityPlannedAt != nil { PlannedActivityView() }

            switch demo.phase {
            case .login: EmptyView()
            case .browsing:
                HStack { control("Pause") { demo.pause() }; control("Interrupt session") { demo.interrupt() } }
            case .paused: control("Resume") { demo.resume() }
            case .review: EmptyView()
            case .failed: control("Try again") { demo.retry() }
            case .done:
                if let receipt = demo.receipt {
                    Label(receipt, systemImage: "checkmark.circle").font(NudgeType.rounded(15))
                        .foregroundStyle(Theme.brandForest).padding(18).frostedSurface(radius: 24)
                        .accessibilityIdentifier("browserDemo.receipt")
                }
                if scenario == .labs || scenario == .visit {
                    control("Open my discussion guide") {
                        model.pendingCareDestination = .visitPrep; model.tab = .care; dismiss()
                    }
                }
                control("Choose another task") { demo.reset() }
            case .stopped: control("Choose another task") { demo.reset() }
            case .idle: EmptyView()
            }
            if demo.canStop { control("Cancel task") { demo.stop() } }
            }
            }
            if demo.phase != .login { composer }
        }
    }

    private var conversation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule().fill(Theme.edge).frame(width: 40, height: 4).frame(maxWidth: .infinity)
            Text("Rumi · working with you").font(NudgeType.rounded(14, .semibold)).foregroundStyle(Theme.brandForest)
            VStack(alignment: .leading, spacing: 12) {
                    Text(demo.activity).font(NudgeType.rounded(14)).foregroundStyle(Theme.inkMuted)
                    ForEach(demo.messages) { message in
                        Text(message.text).font(NudgeType.rounded(14))
                            .padding(12).frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
                            .foregroundStyle(message.isUser ? .white : Theme.ink)
                            .background(message.isUser ? Theme.brandForest : Theme.surface, in: .rect(cornerRadius: 18))
                    }
                }
            if demo.phase != .login {
                HStack {
                    control("Explain this") { demo.followUp("Explain this") }
                }

            }
        }.padding(16).frame(minHeight: 200).frostedSurface(radius: 26)
    }

    private var composer: some View {
        HStack {
            TextField("Ask about this page…", text: $requestText, axis: .vertical)
                .lineLimit(1...3).font(NudgeType.rounded(14)).padding(12)
                .background(Theme.surface, in: .capsule).accessibilityLabel("Ask about this page")
            Button { demo.followUp(requestText); requestText = "" } label: {
                Image(systemName: "arrow.up").frame(width: 48, height: 48)
                    .foregroundStyle(.white).background(Theme.brandForest, in: .circle)
            }.accessibilityLabel("Send follow-up")
                .disabled(requestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || requestText.count > 2000)
        }
    }

    private func control(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(NudgeType.rounded(15, .semibold)).foregroundStyle(Theme.brandForest)
                .padding(.horizontal, 14).frame(minHeight: 48).frame(maxWidth: .infinity)
                .capsuleGlass(tint: Theme.brandMint)
        }
        .buttonStyle(NudgeButtonStyle())
    }

    private func glyph(_ scenario: BrowserDemoModel.Scenario) -> String {
        switch scenario { case .labs: "doc.text.magnifyingglass"; case .visit: "text.book.closed"; case .recipe: "fork.knife"; case .ride: "car"; case .activity: "figure.walk" }
    }

    private func start(_ scenario: BrowserDemoModel.Scenario) {
        let detail: String
        switch scenario {
        case .labs:
            let series = model.resultToAck?.series.flatMap { model.series($0) } ?? model.labSeries.first
            let reading = series.map { "\($0.name): \($0.latest?.value.formatted() ?? "—") \($0.unit)." } ?? "No result available."
            detail = "Review \(model.persona.firstName)’s result. \(reading) Suggested question: \(series?.explainAsk ?? "What should I ask at my next visit?") No diagnosis or medication change is proposed."
        case .visit:
            let doctor = model.appointments.first?.with ?? model.persona.officeName
            let questions = model.guideItems.filter { !$0.resolved }.map(\.text).joined(separator: "\n• ")
            detail = "Discussion guide for \(doctor).\n• \(questions.isEmpty ? "What should we focus on at this visit?" : questions)"
        case .recipe:
            detail = "Chickpea and herb bowl: chickpeas, cucumber, herbs, lemon and olive oil. Adjust ingredients with your care team if you have dietary restrictions."
        case .activity:
            detail = "15-minute gentle mobility & a short walk from @move.kindly: 5 minutes of comfortable standing movement, then a 10-minute easy walk. Follow care-team limits; stop if uncomfortable. Saved as planned, not completed. Fictional post, not a clinical prescription."
        case .ride:
            let appointment = model.appointments.first
            detail = "$24 ride for \(model.persona.firstName) from Home to \(appointment?.location ?? "Clinic") for the visit with \(appointment?.with ?? model.persona.officeName). Pickup: 45 minutes before the appointment."
        }
        demo.start(scenario, patient: model.persona.firstName, detail: detail)
    }
}
