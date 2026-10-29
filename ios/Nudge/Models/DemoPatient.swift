import Foundation

/// Derives sample records from the active synthetic patient, not from an imported source.
enum DemoPatient {
    static func records(for persona: Persona) -> [RecordItem] {
        let labs = persona.labSeries.compactMap { series -> RecordItem? in
            guard let latest = series.latest else { return nil }
            return RecordItem(category: .labs, title: series.name,
                              detail: "\(latest.value.formatted()) \(series.unit) · sample result",
                              date: latest.date, source: "Sample · \(series.provenance)", seriesID: series.id)
        }
        let meds = persona.medications.map {
            RecordItem(category: .medications, title: $0.name, detail: "\($0.dose) · \($0.scheduleLine)",
                       date: .now, source: "Sample · \($0.pharmacy)")
        }
        let conditions = persona.conditions.map {
            RecordItem(category: .conditions, title: $0.name, detail: $0.state,
                       date: .now, source: "Synthetic patient history")
        }
        return labs + meds + conditions
    }
    static func sources(for persona: Persona) -> [RecordSource] {
        [RecordSource(name: "\(persona.firstName)’s sample history", railLabel: "Demo fixture · not imported", connected: false, lastSync: .now)]
    }
    static func memory(for persona: Persona) -> [MemoryItem] {
        [MemoryItem(text: "This is \(persona.firstName)’s synthetic demo, not the user’s medical history.", learnedFrom: "Demo patient"),
         MemoryItem(text: persona.journeys.first?.why ?? "One small step at a time.", learnedFrom: "Sample journey")]
    }
}
