import SwiftUI
import Charts

@MainActor @Observable
final class HealthMeasurements {
    static let shared = HealthMeasurements()
    enum Metric: String, Codable, CaseIterable, Identifiable {
        case weight = "Weight", a1c = "HbA1c", glucose = "Blood glucose", sleep = "Sleep"
        var id: String { rawValue }
        var unit: String { switch self { case .weight: "kg"; case .a1c: "%"; case .glucose: "mg/dL"; case .sleep: "hours" } }
        var validRange: ClosedRange<Double> { switch self { case .weight: 1...600; case .a1c: 1...30; case .glucose: 1...1200; case .sleep: 0...24 } }
    }
    struct Measurement: Codable, Identifiable {
        let id: UUID
        let metric: Metric
        let value: Double
        let date: Date
        let source: String
    }
    private(set) var entries: [Measurement] = []
    private(set) var error: String?
    private let file: URL
    private init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = folder.appendingPathComponent("rumi-measurements-v1.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) { entries = try JSONDecoder().decode([Measurement].self, from: Data(contentsOf: file)) }
        } catch { self.error = "Your saved measurements couldn’t be loaded. Existing data has not been overwritten." }
    }
    func add(metric: Metric, value: Double, date: Date, source: String) throws {
        guard error == nil else { throw CompanionError(message: error!) }
        guard value.isFinite, metric.validRange.contains(value), date <= Date(), !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CompanionError(message: "Enter a valid value, a past or current date and its source.") }
        let entry = Measurement(id: UUID(), metric: metric, value: value, date: date, source: String(source.prefix(200)))
        try save(entries + [entry])
    }
    func remove(_ id: UUID) throws { try save(entries.filter { $0.id != id }) }
    private func save(_ updated: [Measurement]) throws {
        guard error == nil else { throw CompanionError(message: error!) }
        try JSONEncoder().encode(updated).write(to: file, options: [.atomic, .completeFileProtection])
        entries = updated
    }
}

struct HealthTrendsView: View {
    @State private var data = HealthMeasurements.shared
    @State private var metric: HealthMeasurements.Metric = .weight
    @State private var days = 90
    @State private var selected: Date?
    @State private var showAdd = false
    @State private var error: String?
    private var entries: [HealthMeasurements.Measurement] {
        let start = days == 0 ? Date.distantPast : Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return data.entries.filter { $0.metric == metric && $0.date >= start }.sorted { $0.date < $1.date }
    }
    private var highlighted: HealthMeasurements.Measurement? {
        guard let selected else { return entries.last }
        return entries.min { abs($0.date.timeIntervalSince(selected)) < abs($1.date.timeIntervalSince(selected)) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Measurement", selection: $metric) { ForEach(HealthMeasurements.Metric.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                Picker("Date range", selection: $days) { Text("30 days").tag(30); Text("90 days").tag(90); Text("All").tag(0) }.pickerStyle(.segmented)
                if let point = highlighted {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(point.value.formatted(.number.precision(.fractionLength(0...2)))) \(metric.unit)").font(.rumiTitle1.weight(.semibold)).foregroundStyle(Color.brandPrimary)
                        Text(point.date.formatted(date: .abbreviated, time: .shortened)).font(.rumiFootnote)
                        Text(point.source).font(.rumiFootnote).foregroundStyle(Color.labelSecondary)
                    }
                    Chart(entries) { point in
                        LineMark(x: .value("Date", point.date), y: .value(metric.unit, point.value)).foregroundStyle(Color.brandPrimary)
                        PointMark(x: .value("Date", point.date), y: .value(metric.unit, point.value)).foregroundStyle(Color.brandPrimary)
                            .accessibilityLabel("\(metric.rawValue), \(point.date.formatted(date: .abbreviated, time: .omitted)), source: \(point.source)")
                            .accessibilityValue("\(point.value.formatted()) \(metric.unit)")
                        if let selected, point.id == highlighted?.id { RuleMark(x: .value("Selected", selected)).foregroundStyle(Color.brandPrimary.opacity(0.25)) }
                    }
                    .chartXSelection(value: $selected).chartYAxisLabel(metric.unit).frame(height: 220)
                    Text("\(entries.count) recorded measurement\(entries.count == 1 ? "" : "s"). Drag across the chart to inspect dates and sources. Lines connect recorded points; they do not estimate missing days.").font(.rumiFootnote).foregroundStyle(Color.labelSecondary)
                    if let first = entries.first, let last = entries.last, entries.count > 1 {
                        LabeledContent("Change across recorded points", value: "\((last.value - first.value).formatted(.number.precision(.fractionLength(0...2)))) \(metric.unit)").font(.rumiSubheadline)
                    }
                    ForEach(entries.reversed()) { point in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(point.date.formatted(date: .abbreviated, time: .shortened)).font(.rumiSubheadline)
                                Text(point.source).font(.rumiFootnote).foregroundStyle(Color.labelSecondary)
                            }
                            Spacer()
                            Text("\(point.value.formatted()) \(metric.unit)").font(.rumiSubheadline)
                            Button(role: .destructive) {
                                do { try data.remove(point.id) } catch { self.error = error.localizedDescription }
                            } label: { Image(systemName: "trash").frame(width: 44, height: 44) }.accessibilityLabel("Delete measurement")
                        }.padding(12).glassCard()
                    }
                } else {
                    ContentUnavailableView("No measurements in this range", systemImage: "chart.xyaxis.line", description: Text("Add dated measurements from your own records. Charts never use the example Health records or invented personal data."))
                }
                if let error = error ?? data.error { Text(error).foregroundStyle(.red) }
            }.padding(20)
        }
        .background { AmbientBackground() }.navigationTitle("Health trends")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Add", systemImage: "plus") { showAdd = true } } }
        .sheet(isPresented: $showAdd) { AddMeasurementView(initialMetric: metric) }
        .onChange(of: metric) { _, _ in selected = nil }
        .onChange(of: days) { _, _ in selected = nil }
    }
}
private struct AddMeasurementView: View {
    let initialMetric: HealthMeasurements.Metric
    @Environment(\.dismiss) private var dismiss
    @State private var metric: HealthMeasurements.Metric = .weight
    @State private var value = ""
    @State private var date = Date()
    @State private var source = "Self-reported"
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Picker("Measurement", selection: $metric) { ForEach(HealthMeasurements.Metric.allCases) { Text($0.rawValue).tag($0) } }
                TextField("Value in \(metric.unit)", text: $value).keyboardType(.decimalPad)
                DatePicker("Recorded at", selection: $date, in: ...Date())
                TextField("Source", text: $source)
                Text("Enter the units shown above. These are your transcribed observations, not independently verified or automatically imported medical records.").font(.footnote).foregroundStyle(.secondary)
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Add measurement").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let formatter = NumberFormatter(); formatter.locale = .current; formatter.numberStyle = .decimal
                        guard let amount = formatter.number(from: value)?.doubleValue else { error = "Enter a numeric value."; return }
                        do { try HealthMeasurements.shared.add(metric: metric, value: amount, date: date, source: source); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }
                }
            }.onAppear { metric = initialMetric }
        }
    }
}
