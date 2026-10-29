import Foundation
import Testing
@testable import Nudge

@MainActor
struct NudgeTests {
    @Test func chatNavigationNeverGrantsApproval() {
        let demo = BrowserDemoModel()
        demo.start(.ride, patient: "Marcus", detail: "Sample $24 ride to Clinic")
        demo.followUp("Continue")
        #expect(demo.messages.isEmpty)
        demo.continueDemoLogin()
        demo.followUp("Explain this")
        #expect(demo.messages.last?.text.contains("$24") == true)
        demo.followUp("Show next step")
        #expect(demo.step == 1)
        demo.followUp("Pause"); demo.followUp("Continue")
        #expect(demo.phase == .paused)
        #expect(demo.step == 1)
        demo.followUp("Resume"); demo.followUp("Continue"); demo.followUp("Continue")
        demo.followUp("Approve and book")
        #expect(demo.phase == .review)
        #expect(demo.receipt == nil)
        demo.followUp("Stop")
        #expect(demo.phase == .stopped)
        demo.reset()
        #expect(demo.messages.isEmpty)
    }

    @Test func approvalIsRequiredEvenWhenCollapsed() {
        let demo = BrowserDemoModel()
        demo.start(.visit, patient: "Marcus", detail: "Sample questions")
        demo.approve()
        #expect(demo.phase == .login)
        #expect(demo.receipt == nil)
        demo.continueDemoLogin()
        demo.advance(); demo.advance(); demo.advance()
        demo.isCollapsed = true
        #expect(demo.phase == .review)
        #expect(demo.statusLabel == "Needs your okay")
        demo.approve()
        #expect(demo.phase == .done)
        #expect(demo.receipt?.contains("Task summary") == true)
        #expect(demo.receipt?.contains("no external action taken") == true)
    }

    @Test func pauseCancellationAndFailureCannotCompleteActions() {
        let demo = BrowserDemoModel()
        demo.start(.ride, patient: "Marcus", detail: "Sample $24 ride")
        demo.continueDemoLogin(); demo.pause(); demo.advance(); demo.approve()
        #expect(demo.phase == .paused)
        #expect(demo.step == 0)
        demo.resume(); demo.interrupt(); demo.approve()
        #expect(demo.phase == .failed)
        #expect(demo.receipt == nil)
        demo.retry()
        #expect(demo.phase == .login)
        demo.stop(); demo.advance(); demo.approve()
        #expect(demo.phase == .stopped)
        #expect(demo.receipt == nil)
    }

    @Test func changedFareRequiresFreshReview() {
        let demo = BrowserDemoModel()
        demo.start(.ride, patient: "Marcus", detail: "Sample $24 ride")
        demo.continueDemoLogin(); demo.advance(); demo.advance(); demo.advance()
        demo.changeFare()
        #expect(demo.reviewText.contains("$29"))
        demo.approve()
        #expect(demo.receipt == nil)
        demo.advance(); demo.approve()
        #expect(demo.receipt?.contains("$29") == true)
    }

    @Test func declineNeverCreatesReceipt() {
        let demo = BrowserDemoModel()
        demo.start(.visit, patient: "Marcus", detail: "Sample message")
        demo.continueDemoLogin(); demo.advance(); demo.advance(); demo.advance()
        demo.stop(); demo.approve()
        #expect(demo.phase == .stopped)
        #expect(demo.receipt == nil)
    }

    @Test func localActivityPlansDoNotNeedSubmissionApproval() {
        let demo = BrowserDemoModel()
        var completed: BrowserDemoModel.Scenario? = nil
        demo.onLocalCompletion = { completed = $0 }
        demo.start(.activity, patient: "Marcus", detail: "Planned, not completed")
        demo.continueDemoLogin(); demo.advance(); demo.advance(); demo.advance()
        #expect(demo.phase == .done)
        #expect(completed == .activity)
        #expect(demo.receipt?.contains("not completion logs") == true)
        demo.reset()
    }

    @Test func modelTextCannotCreateExternalActionCards() {
        #expect(CompanionEngine.parse("Ready [[refill:Medicine|Ready at pharmacy]]").rich == .none)
        #expect(CompanionEngine.parse("Done [[action:Book|Pay now]]").rich == .none)
        #expect(CompanionEngine.parse("Offer [[program:Sponsor]]").rich == .none)
    }

    @Test func memoryCandidatesRequireConfirmationAndExpire() {
        let candidate = MemoryItem(text: "I prefer evenings", learnedFrom: "Your conversation", at: .now, confidence: 0.3, confirmed: false)
        #expect(!candidate.isUsable)
        let old = MemoryItem(text: "Old preference", learnedFrom: "Confirmed by you", at: Date(timeIntervalSinceNow: -46 * 86400), confirmed: true)
        #expect(!old.isUsable)
    }

    @Test func sampleRecordsFollowEveryPersonaWithoutConnections() {
        for pathway in CarePathway.allCases {
            let persona = PersonaFixtures.persona(for: pathway)
            let records = DemoPatient.records(for: persona)
            #expect(records.filter { $0.category == .medications }.count == persona.medications.count)
            #expect(records.filter { $0.category == .conditions }.count == persona.conditions.count)
            #expect(records.filter { $0.category == .labs }.allSatisfy { record in persona.labSeries.contains { $0.id == record.seriesID } })
            #expect(DemoPatient.sources(for: persona).allSatisfy { !$0.connected })
            #expect(DemoPatient.memory(for: persona).first?.text.contains(persona.firstName) == true)
        }
    }

    @Test func aiAndMemoryAreOnByDefaultWithStableDeviceID() {
        UserDefaults.standard.removeObject(forKey: "rumi.ai.consent")
        UserDefaults.standard.removeObject(forKey: "rumi.ai.memory")
        let privacy = AIPrivacy()
        #expect(privacy.processingConsent)
        #expect(privacy.memoryConsent)
        #expect(privacy.deviceID.count >= 20)
        #expect(AIPrivacy().deviceID == privacy.deviceID)
    }

    @Test func profileMemoryIsIsolatedPerProfileAndDropsFailedReplies() {
        ProfileMemoryStore.wipeAll()
        let turns = [ConversationTurn(role: .user, text: "I walk after lunch"), ConversationTurn(role: .companion, text: "Live AI unavailable · offline")]
        ProfileMemoryStore.save(ProfileMemory(memory: [MemoryItem(text: "Marcus-only", learnedFrom: "Your conversation")], turns: ProfileMemoryStore.restorable(turns)), for: "metabolic")
        #expect(ProfileMemoryStore.load("metabolic")?.memory.first?.text == "Marcus-only")
        #expect(ProfileMemoryStore.load("metabolic")?.turns == [SavedTurn(role: "user", text: "I walk after lunch")])
        #expect(ProfileMemoryStore.load("oncology") == nil)
        ProfileMemoryStore.wipeAll()
        #expect(ProfileMemoryStore.load("metabolic") == nil)
    }

    @Test func resetClearsAllBrowserPatientState() {
        let demo = BrowserDemoModel()
        demo.start(.labs, patient: "Marcus", detail: "Sample result")
        demo.continueDemoLogin(); demo.advance(); demo.advance(); demo.advance(); demo.approve()
        demo.reset()
        #expect(demo.phase == .idle)
        #expect(demo.patientName.isEmpty)
        #expect(demo.reviewText.isEmpty)
        #expect(demo.receipt == nil)
        #expect(demo.scenario == nil)
    }
}
