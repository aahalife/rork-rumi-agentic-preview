import Foundation
import Testing
@testable import Rumi

@MainActor @Suite(.serialized)
struct RumiInsightsTests {
    let anchor = Date(timeIntervalSince1970: 1_793_275_200)
    func query(_ operation: DemoInsightQuery.Operation, _ metrics: [DemoMetric], days: Int? = nil, count: Int? = nil) -> DemoInsightQuery {
        DemoInsightQuery(operation: operation, metrics: metrics, days: days, count: count)
    }
    @Test func primaryNumbersAreSuppliedAndNotMaria() throws {
        let result = try DemoInsightEngine.evaluate(query(.trend, [.a1c]), member: .primary, anchor: anchor)
        #expect(result.series[0].observations.map(\.value) == [9, 8.8])
        #expect(result.facts.contains("percentage points"))
        #expect(!result.facts.contains("7.8"))
        #expect(result.series[0].limitation.contains("illustrative"))
        #expect(DemoInsightEngine.observations(member: .primary, metric: .weight, anchor: anchor).isEmpty)
    }
    @Test func latestAndLastNDoNotInventResults() throws {
        let latest = try DemoInsightEngine.evaluate(query(.latest, [.a1c]), member: .primary, anchor: anchor)
        #expect(latest.series[0].observations.map(\.value) == [8.8])
        let last = try DemoInsightEngine.evaluate(query(.lastN, [.a1c], count: 4), member: .maria, anchor: anchor)
        #expect(last.series[0].observations.map(\.value) == [8.6, 8.2, 7.8])
        #expect(last.series[0].limitation.contains("fewer than requested"))
        let two = try DemoInsightEngine.evaluate(query(.lastN, [.a1c], count: 2), member: .maria, anchor: anchor)
        #expect(two.series[0].observations.map(\.value) == [8.2, 7.8])
    }
    @Test func sideBySidePreservesUnitsAndIndependentDates() throws {
        let result = try DemoInsightEngine.evaluate(query(.sideBySide, [.a1c, .weight]), member: .tom, anchor: anchor)
        #expect(result.series.count == 2)
        #expect(result.series[0].observations.count == 1)
        #expect(result.series[1].observations.count == 4)
        #expect(result.series[0].metric.unit == "%")
        #expect(result.series[1].metric.unit == "lb")
        #expect(result.series[0].observations.first?.date != result.series[1].observations.first?.date)
    }
    @Test func rangesAreInclusiveAndMissingNotZero() throws {
        let empty = try DemoInsightEngine.evaluate(query(.trend, [.a1c], days: 30), member: .primary, anchor: anchor)
        #expect(empty.series[0].observations.isEmpty)
        let partial = try DemoInsightEngine.evaluate(query(.trend, [.a1c], days: 90), member: .primary, anchor: anchor)
        #expect(partial.series[0].observations.map(\.value) == [8.8])
        let sleep = try DemoInsightEngine.evaluate(query(.trend, [.sleep], days: 14), member: .tom, anchor: anchor)
        #expect(sleep.series[0].observations.count == 14)
    }
    @Test func unsupportedDataReturnsUnavailableNotSyntheticClaims() throws {
        for member in DemoMember.allCases {
            for metric in [DemoMetric.bmi, .glucose] {
                let result = try DemoInsightEngine.evaluate(query(.trend, [metric]), member: member, anchor: anchor)
                #expect(result.series[0].observations.isEmpty)
            }
            let cohort = try DemoInsightEngine.evaluate(query(.cohort, [.a1c]), member: member, anchor: anchor)
            #expect(cohort.facts.contains("No validated comparison dataset"))
            let tir = try DemoInsightEngine.evaluate(query(.timeInRange, [.tir]), member: member, anchor: anchor)
            #expect(tir.series[0].observations.isEmpty)
            #expect(!tir.facts.contains("70%"))
        }
    }
    @Test func clinicalDescriptionsAreNeutral() throws {
        let ldl = try DemoInsightEngine.evaluate(query(.trend, [.ldl]), member: .primary, anchor: anchor)
        #expect(ldl.facts.contains("unchanged"))
        let egfr = try DemoInsightEngine.evaluate(query(.trend, [.egfr]), member: .primary, anchor: anchor)
        #expect(egfr.series[0].observations.map(\.value) == [60, 55])
        for word in ["better", "worse", "abnormal", "healthy", "on target", "because"] { #expect(!egfr.facts.lowercased().contains(word)) }
    }
    @Test func strictToolArgumentsRejectInjectionAndInvalidBounds() throws {
        let valid = "{\"requests\":[{\"operation\":\"trend\",\"metrics\":[\"HbA1c\"]}]}"
        #expect(try DemoInsightEngine.parseQueries(valid).count == 1)
        for invalid in [
            "{\"requests\":[]}",
            "{\"requests\":[{\"operation\":\"trend\",\"metrics\":[\"HbA1c\"],\"patient_id\":\"other\"}]}",
            "{\"requests\":[{\"operation\":\"trend\",\"metrics\":[\"HbA1c\"],\"days\":-1}]}",
            "{\"requests\":[{\"operation\":\"lastN\",\"metrics\":[\"HbA1c\"],\"count\":21}]}",
            "{\"requests\":[{\"operation\":\"sideBySide\",\"metrics\":[\"HbA1c\"]}]}",
            "{\"requests\":[{\"operation\":\"trend\",\"metrics\":[\"HbA1c\",\"HbA1c\"]}]}",
            "{\"requests\":[{\"operation\":\"lastN\",\"metrics\":[\"HbA1c\"]}]}",
            "{\"requests\":[{\"operation\":\"timeInRange\",\"metrics\":[\"HbA1c\"]}]}",
            "{\"requests\":[{\"operation\":\"trend\",\"metrics\":[\"made-up\"]}]}"
        ] { #expect(throws: (any Error).self) { try DemoInsightEngine.parseQueries(invalid) } }
    }
    @Test func multipleRequestsRemainSeparate() throws {
        let queries = try DemoInsightEngine.parseQueries("{\"requests\":[{\"operation\":\"sideBySide\",\"metrics\":[\"HbA1c\",\"eGFR\"]},{\"operation\":\"latest\",\"metrics\":[\"LDL-C\"]}]}")
        let results = try queries.map { try DemoInsightEngine.evaluate($0, member: .primary, anchor: anchor) }
        #expect(results.count == 2)
        #expect(results[0].series.count == 2)
        #expect(results[1].series[0].observations.map(\.value) == [130])
    }
    @Test func numberMentionsAndDeviceProblemsDoNotTriggerLookups() {
        for text in ["The 6.2 scared me", "My Dexcom sensor fell off", "I want a better bedtime", "Yes", "What is your name?", "Show my glucose, I have chest pain"] { #expect(!DemoInsightEngine.isExplicitDataRequest(text)) }
        for text in ["Show my last 4 A1cs", "Compare my A1c with women like me", "My steps and A1c over 6 months", "Show CGM time in range"] { #expect(DemoInsightEngine.isExplicitDataRequest(text)) }
    }
    @Test func persistenceRemainsBackwardCompatible() throws {
        let old = Data("{\"role\":\"assistant\",\"text\":\"Hello\",\"id\":\"00000000-0000-0000-0000-000000000001\",\"kind\":\"conversation\"}".utf8)
        let turn = try JSONDecoder().decode(DemoTurn.self, from: old)
        #expect(turn.insights == nil)
        let insight = try DemoInsightEngine.evaluate(query(.trend, [.a1c]), member: .primary, anchor: anchor)
        let new = DemoTurn(role: "assistant", text: "Facts", kind: "calculated-insight", insights: [insight], invitesGoal: true)
        let copy = try JSONDecoder().decode(DemoTurn.self, from: JSONEncoder().encode(new))
        #expect(copy.insights?.first?.series[0].observations.map(\.value) == [9, 8.8])
        #expect(copy.invitesGoal == true)
    }
    @Test func apiRequestMatchesContractAndKeepsBasePath() throws {
        let settings = RumiAPISettings(baseURL: "https://example.com/functions/v1/rumi-app-api", appID: "00000000-0000-0000-0000-000000000001")
        let request = try RumiAppAPI.makeRequest(settings: settings, path: "v1/goals", method: "POST", body: ["text": "A chosen goal", "quote": "A chosen goal"], token: "user-session", idempotencyKey: "review-1")
        #expect(request.url?.path == "/functions/v1/rumi-app-api/v1/goals")
        #expect(request.value(forHTTPHeaderField: "x-rumi-app-id") == settings.appID)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer user-session")
        #expect(request.value(forHTTPHeaderField: "Idempotency-Key") == "review-1")
        #expect(request.value(forHTTPHeaderField: "x-rumi-server-key") == nil)
        #expect(request.httpMethod == "POST")
        #expect(throws: (any Error).self) { try RumiAPISettings(baseURL: "http://example.com", appID: settings.appID).validatedURL() }
        #expect(throws: (any Error).self) { try RumiAPISettings(baseURL: "https://u:p@example.com", appID: settings.appID).validatedURL() }
    }
    @Test func httpSuccessIsNotCommitProof() throws {
        for json in ["{}", "{\"status\":\"ok\"}", "{\"committed\":null}", "{\"committed\":false}"] {
            #expect(!(try JSONDecoder().decode(RumiAPIReceipt.self, from: Data(json.utf8))).confirmed)
        }
        #expect(try JSONDecoder().decode(RumiAPIReceipt.self, from: Data("{\"committed\":true}".utf8)).confirmed)
    }
    @Test func demoBlocksExistingAccountConfigurationAndRequests() async {
        let previous = DemoSession.shared.isPresented
        DemoSession.shared.isPresented = true
        defer { DemoSession.shared.isPresented = previous }
        let api = RumiAppAPI(persist: false)
        #expect(throws: (any Error).self) { try api.configure(RumiAPISettings(baseURL: "https://example.com", appID: "00000000-0000-0000-0000-000000000001")) }
        do { _ = try await api.health(); Issue.record("Demo must never request real-account API data") } catch { #expect(error.localizedDescription.contains("blocked")) }
    }
}
