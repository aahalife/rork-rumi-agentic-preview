import SwiftUI
import Charts

// The model selects queries. Only this repository supplies numbers, dates and chart points.
enum DemoMetric: String, Codable, CaseIterable, Identifiable {
    case a1c = "HbA1c", ldl = "LDL-C", egfr = "eGFR", weight = "Weight"
    case sleep = "Sleep", steps = "Activity", bmi = "BMI", glucose = "CGM glucose", tir = "Time in range"
    var id: String { rawValue }
    var unit: String {
        switch self {
        case .a1c, .tir: "%"
        case .ldl, .glucose: "mg/dL"
        case .egfr: "mL/min/1.73 m²"
        case .weight: "lb"
        case .sleep: "hours"
        case .steps: "steps"
        case .bmi: "kg/m²"
        }
    }
    static func available(for member: DemoMember) -> [Self] {
        switch member { case .primary: [.a1c, .ldl, .egfr]; case .maria: [.a1c, .weight]; case .tom: [.a1c, .weight, .sleep, .steps] }
    }
}

struct DemoInsightObservation: Codable, Identifiable, Equatable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct DemoInsightQuery: Codable, Equatable {
    enum Operation: String, Codable { case latest, trend, lastN, sideBySide, cohort, timeInRange }
    let operation: Operation
    let metrics: [DemoMetric]
    let days: Int?
    let count: Int?
    func validate() throws {
        guard (1...2).contains(metrics.count), Set(metrics).count == metrics.count,
              days == nil || (1...3650).contains(days!), count == nil || (1...20).contains(count!),
              (operation == .sideBySide ? metrics.count == 2 : metrics.count == 1),
              (operation != .lastN || count != nil),
              (operation != .timeInRange || metrics == [.tir]) else {
            throw CompanionError(message: "The insight request was not valid. Ask for one measure, or two side by side.")
        }
    }
}

struct DemoInsightSeries: Codable, Identifiable {
    var id: String { metric.rawValue }
    let metric: DemoMetric
    let observations: [DemoInsightObservation]
    let facts: [String]
    let limitation: String
}

struct DemoInsight: Codable, Identifiable {
    var id = UUID()
    let member: DemoMember
    let query: DemoInsightQuery
    let series: [DemoInsightSeries]
    let baseline: Date
    var title: String { query.operation == .sideBySide ? "Side by side · Not a relationship" : query.operation == .cohort ? "Comparison data unavailable" : "Your sample numbers" }
    var facts: String { series.flatMap(\.facts).joined(separator: "\n") }
}

enum DemoInsightEngine {
    static func observations(member: DemoMember, metric: DemoMetric, anchor: Date) -> [DemoInsightObservation] {
        guard DemoMetric.available(for: member).contains(metric) else { return [] }
        let offsets: [Int], values: [Double]
        if member == .primary {
            offsets = [270, 70]
            values = metric == .ldl ? [130, 130] : metric == .egfr ? [60, 55] : [9, 8.8]
        } else {
            switch metric {
            case .weight:
                offsets = [92, 60, 30, 0]; values = member == .maria ? [216.7, 214.2, 211.4, 208.7] : [228, 226.5, 225.8, 224]
            case .sleep:
                offsets = (0..<14).map { 13 - $0 }; values = (0..<14).map { 6.4 + [0.2, -0.4, 0.5, -0.1, -0.3, 0.1, 0.0][$0 % 7] }
            case .steps:
                offsets = (0..<14).map { 13 - $0 }; values = (0..<14).map { Double(4800 + [400, -600, 800, -300, -400, 100, 0][$0 % 7]) }
            default:
                offsets = member == .maria ? [92, 50, 0] : [0]; values = member == .maria ? [8.6, 8.2, 7.8] : [5.8]
            }
        }
        return zip(offsets, values).compactMap { offset, value in
            Calendar.current.date(byAdding: .day, value: -offset, to: anchor).map { DemoInsightObservation(date: $0, value: value) }
        }.sorted { $0.date < $1.date }
    }
    static func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...2))) }
    static func evaluate(_ query: DemoInsightQuery, member: DemoMember, anchor: Date) throws -> DemoInsight {
        try query.validate()
        let series = query.metrics.map { metric -> DemoInsightSeries in
            if query.operation == .cohort {
                return DemoInsightSeries(metric: metric, observations: [], facts: ["No validated comparison dataset is installed for this demo."], limitation: "No percentile, peer average or demographic match was inferred.")
            }
            if query.operation == .timeInRange || metric == .tir {
                return DemoInsightSeries(metric: metric, observations: [], facts: ["No CGM readings or coverage interval are available to calculate time in range."], limitation: "No target or synthetic percentage was substituted.")
            }
            var points = observations(member: member, metric: metric, anchor: anchor)
            if let days = query.days, let start = Calendar.current.date(byAdding: .day, value: -days, to: anchor) { points = points.filter { $0.date >= start && $0.date <= anchor } }
            let available = points.count
            if query.operation == .latest { points = Array(points.suffix(1)) }
            if query.operation == .lastN { points = Array(points.suffix(query.count ?? 4)) }
            guard !points.isEmpty else {
                return DemoInsightSeries(metric: metric, observations: [], facts: ["No \(metric.rawValue) observations are available for this member in the requested period."], limitation: "Missing observations are not zeros. Try All or choose another measure; BMI requires height and weight, and CGM requires actual readings.")
            }
            let facts = points.map { point in
                let label = member == .primary ? (point == observations(member: member, metric: metric, anchor: anchor).first ? "Earlier supplied result" : "Repeat supplied result") : point.date.formatted(date: .abbreviated, time: .omitted)
                return "\(metric.rawValue): \(number(point.value)) \(metric.unit) · \(label)."
            }
            var descriptions = facts
            if query.operation != .latest, let first = points.first, let last = points.last, points.count > 1 {
                let delta = last.value - first.value
                let unit = metric == .a1c || metric == .tir ? "percentage points" : metric.unit
                descriptions.append(delta == 0 ? "First-to-last change: unchanged." : "First-to-last change: \(delta > 0 ? "+" : "")\(number(delta)) \(unit).")
            }
            var limitation = member == .primary ? "Supplied fictional scenario. Dates on this chart are illustrative, not actual lab dates." : "Fictional sample observations. Dates are anchored to the saved demo baseline; intermediate weights are synthetic."
            if query.operation == .lastN, available < (query.count ?? 4) { limitation += " Only \(available) results are available, fewer than requested." }
            limitation += " No lab reference ranges were supplied. No clinical assessment or cause is inferred."
            return DemoInsightSeries(metric: metric, observations: points, facts: descriptions, limitation: limitation)
        }
        return DemoInsight(member: member, query: query, series: series, baseline: anchor)
    }
    // Conservative intent gate: a mention or a worried number alone never starts a lookup.
    static func isExplicitDataRequest(_ text: String) -> Bool {
        let intent = text.range(of: "(?i)\\b(show|plot|chart|compare|comparison|latest|last \\d+|trend|over time|over (?:the last )?\\d+ (?:days|weeks|months|years)|side by side|time in range|how many|what (?:is|was|are|were)|review my (?:repeat )?labs)\\b", options: .regularExpression) != nil
        let measure = text.range(of: "(?i)\\b(a1cs?|hba1cs?|ldl|egfr|weight|bmi|sleep|steps|activity|glucose|cgm|labs|time in range)\\b", options: .regularExpression) != nil
        let urgent = text.range(of: "(?i)\\b(chest pain|can.t breathe|fainting|unconscious|seizure|low (?:blood )?(?:glucose|sugar)|suicid|kill myself)\\b", options: .regularExpression) != nil
        return intent && measure && !urgent
    }
    static func parseQueries(_ arguments: String) throws -> [DemoInsightQuery] {
        guard let data = arguments.data(using: .utf8), let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], Set(object.keys) == ["requests"],
              let rows = object["requests"] as? [[String: Any]], (1...4).contains(rows.count),
              rows.allSatisfy({ Set($0.keys).isSubset(of: ["operation", "metrics", "days", "count"]) }) else { throw CompanionError(message: "The model returned an invalid insight request; no chart was created.") }
        struct Envelope: Decodable { let requests: [DemoInsightQuery] }
        let queries = try JSONDecoder().decode(Envelope.self, from: data).requests
        try queries.forEach { try $0.validate() }
        return queries
    }
    static var tool: [String: Any] {
        ["type": "function", "function": ["name": "read_demo_insights", "description": "Read-only deterministic fictional-member facts and inline charts. For explicit data requests only, not mentions in coaching. Bundle up to four requests. Never supply numbers, dates, patient IDs or diagnoses. Use sideBySide for exactly two measures; others use one. Missing and cohort data return honest unavailable cards.", "parameters": ["type": "object", "properties": ["requests": ["type": "array", "minItems": 1, "maxItems": 4, "items": ["type": "object", "properties": ["operation": ["type": "string", "enum": ["latest", "trend", "lastN", "sideBySide", "cohort", "timeInRange"]], "metrics": ["type": "array", "items": ["type": "string", "enum": DemoMetric.allCases.map(\.rawValue)], "minItems": 1, "maxItems": 2], "days": ["type": "integer", "minimum": 1, "maximum": 3650], "count": ["type": "integer", "minimum": 1, "maximum": 20]], "required": ["operation", "metrics"], "additionalProperties": false]]], "required": ["requests"], "additionalProperties": false]]]
    }
}

struct DemoInsightCard: View {
    let insight: DemoInsight
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(insight.title, systemImage: "chart.xyaxis.line").font(.title3.bold())
            Text("Demo · \(insight.member.name) · Calculated facts").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(insight.query.days.map { "Requested period: last \($0) days" } ?? "Requested period: all available sample dates").font(.footnote)
            ForEach(insight.series) { series in DemoInsightSeriesView(series: series, baseline: insight.baseline) }
            if insight.series.count == 2 { Text("Each series retains its own dates and unit. No correlation or causal relationship is calculated.").font(.footnote) }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 24))
            .overlay { RoundedRectangle(cornerRadius: 24).stroke(Color.brandPrimary.opacity(0.18)) }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("demo.insight.card")
    }
}

private struct DemoInsightSeriesView: View {
    let series: DemoInsightSeries
    let baseline: Date
    @State private var selected: Date?
    @State private var range = 0
    private var points: [DemoInsightObservation] {
        guard range > 0, let start = Calendar.current.date(byAdding: .day, value: -range, to: baseline) else { return series.observations }
        return series.observations.filter { $0.date >= start }
    }
    private var focused: DemoInsightObservation? {
        guard let selected else { return points.last }
        return points.min { abs($0.date.timeIntervalSince(selected)) < abs($1.date.timeIntervalSince(selected)) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(series.metric.rawValue).font(.headline)
            if !series.observations.isEmpty {
                Picker("Visible chart range for \(series.metric.rawValue)", selection: $range) { Text("30d").tag(30); Text("90d").tag(90); Text("All").tag(0) }.pickerStyle(.segmented)
                if points.isEmpty { Text("No observations in this window. Select All to see the requested sample results.").font(.callout) }
            }
            if let point = focused {
                Text("\(DemoInsightEngine.number(point.value)) \(series.metric.unit)").font(.title2.bold()).foregroundStyle(Color.brandPrimary).accessibilityIdentifier("demo.insight.focused")
                Text("Illustrative sample date · \(point.date.formatted(date: .abbreviated, time: .omitted))").font(.caption)
                Chart(points) { point in
                    if points.count > 1 { LineMark(x: .value("Sample date", point.date), y: .value(series.metric.unit, point.value)).foregroundStyle(Color.brandPrimary) }
                    PointMark(x: .value("Sample date", point.date), y: .value(series.metric.unit, point.value)).foregroundStyle(Color.brandPrimary)
                        .accessibilityLabel("\(series.metric.rawValue), illustrative date \(point.date.formatted(date: .abbreviated, time: .omitted))")
                        .accessibilityValue("\(DemoInsightEngine.number(point.value)) \(series.metric.unit)")
                }.frame(height: 170).chartXSelection(value: $selected).chartYAxisLabel(series.metric.unit)
                Text("Drag to inspect · \(points.count) observations. Lines only connect sample points.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(series.facts.enumerated()), id: \.offset) { _, fact in Text(fact).font(.callout).textSelection(.enabled) }
            Text(series.limitation).font(.footnote).foregroundStyle(.secondary)
            if !points.isEmpty {
                DisclosureGroup("Accessible values & sample dates") {
                    ForEach(points) { point in LabeledContent(point.date.formatted(date: .abbreviated, time: .omitted), value: "\(DemoInsightEngine.number(point.value)) \(series.metric.unit)").padding(.vertical, 4) }
                }.accessibilityIdentifier("demo.insight.values")
            }
        }.accessibilityElement(children: .contain).onChange(of: range) { _, _ in selected = nil }
    }
}

struct DemoInsightsWalkthrough: View {
    @Environment(\.dismiss) private var dismiss
    @State private var demo = DemoSession.shared
    var body: some View {
        List {
            Section {
                Text("Numbers first. Your next step, only if you want.").font(.title2.bold())
                Text("Sonnet 5.5 selects read-only queries. The app calculates facts and builds charts from this fictional member’s records. No lab assessment, diagnosis or medication changes.")
            }
            Section("Ask Rumi · Live Sonnet 5.5") {
                example("My numbers over time", demo.member == .primary ? "Show my A1c and eGFR side by side, and also my latest LDL." : demo.member == .maria ? "Show my A1c and weight side by side." : "Show my steps and sleep side by side over the last 14 days.")
                example("My last four results", "Show my last 4 A1c results. If fewer exist, show only those available.")
                example("An honest missing-data answer", "Compare my A1c with people like me and show my CGM time in range.")
                Text("These buttons send a real request, not a scripted AI answer. Cards contain locally calculated sample facts.").font(.footnote)
            }
            Section("Calculated preview · No AI request") {
                if let preview = try? DemoInsightEngine.evaluate(DemoInsightQuery(operation: .trend, metrics: [.a1c], days: nil, count: nil), member: demo.member, anchor: demo.state.anchorDate ?? Calendar.current.startOfDay(for: Date())) { DemoInsightCard(insight: preview) }
                Text("This preview is built by the app. Use the Ask Rumi buttons above to exercise live Sonnet query selection.").font(.footnote)
            }
            Section("Rehearse a follow-up · Not sent") {
                NavigationLink("Refill, referral & lab follow-ups") { DemoCareFollowupsView() }.accessibilityIdentifier("demo.care.followups")
                Text("Answer buttons are bound to an exact local question. No pharmacy, provider directory, calendar, lab booking or clinical record is changed.").font(.footnote)
            }
            Section("Coaching after the answer") {
                Text("After a data answer, accept the next-step invitation to get one open question about your goal. A worried mention of a number stays in the conversation. Tips are offered only when you ask for ideas.")
                Text("Peer comparisons, BMI and CGM are unavailable when required data is absent; the app does not invent them.")
            }
        }.navigationTitle("Insights walkthrough").demoLabel()
    }
    private func example(_ title: String, _ prompt: String) -> some View {
        Button { demo.send(prompt); dismiss() } label: { VStack(alignment: .leading, spacing: 6) { Text(title).font(.headline); Text(prompt).font(.callout).foregroundStyle(.secondary) }.padding(.vertical, 8).frame(minHeight: 44) }.disabled(demo.busy)
    }
}

struct DemoCareFollowupsView: View {
    @State private var demo = DemoSession.shared
    @State private var review: Review?
    private struct Review: Identifiable { let id = UUID(); let member: DemoMember; let revision: UUID; let kind: String; let question: String; let answer: String }
    var body: some View {
        List {
            Section { Text("Seeded follow-up rehearsals · These are not supplied active orders or actual reminder deliveries. Answers save a local receipt only; they never stop medication, make a referral or complete a lab order.").font(.callout) }
            followup("Refill reminder", "Would you like to prepare a refill question for your prescriber?", ["Prepare a question", "Not now"])
            followup("Specialist referral", "Would you like to rehearse asking your care team about a referral?", ["Prepare my questions", "Not now"])
            followup("Lab follow-up", "Would you like to rehearse planning a blood draw?", ["Review planning steps", "Not now"])
            Section("Local follow-up history") {
                ForEach(demo.state.receipts.filter { $0.text.hasPrefix("Care rehearsal") }) { receipt in Text(receipt.text); Text(receipt.date.formatted()).font(.caption).foregroundStyle(.secondary) }
            }
        }.navigationTitle("Care follow-ups").demoLabel()
            .sheet(item: $review) { item in
                NavigationStack {
                    Form {
                        Section("Exact question") { Text(item.question) }
                        Section("Your selected answer") { Text(item.answer); Text("\(item.member.name) · \(item.kind)") }
                        Section {
                            Button("Confirm local rehearsal · Not sent") {
                                guard demo.member == item.member, demo.revision == item.revision else { review = nil; return }
                                demo.receipt("Care rehearsal · \(item.kind) · Question: \(item.question) Answer: \(item.answer). Simulated · Not sent. No medication, referral, calendar or lab order changed.")
                                review = nil
                            }.disabled(demo.member != item.member || demo.revision != item.revision)
                        } footer: { Text("No provider search was performed. No slots are available or booked. Calendar access is not requested. Labcorp is not loaded or automated.") }
                    }.navigationTitle("Review rehearsal").toolbar { Button("Cancel") { review = nil } }
                }
            }
            .onChange(of: demo.revision) { _, _ in review = nil }
    }
    private func followup(_ kind: String, _ question: String, _ answers: [String]) -> some View {
        Section(kind) {
            Text(question)
            ForEach(answers, id: \.self) { answer in Button(answer) { review = Review(member: demo.member, revision: demo.revision, kind: kind, question: question, answer: answer) }.frame(minHeight: 44) }
        }
    }
}
