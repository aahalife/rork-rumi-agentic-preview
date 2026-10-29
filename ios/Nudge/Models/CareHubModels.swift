import Foundation

/// The Care hub data spine (v5 §4.4) — appointments, the care plan,
/// medications, records and visit prep, all rendered from these models. Calm but utilitarian: every
/// value carries provenance and freshness, and nothing consequential happens
/// without an explicit, equal-weight confirmation (§2.2, §5.5).

// MARK: - Navigation

/// Type-safe destinations inside Care. Today's "Needs you" routes here too.
/// Messaging, refills, bills, payments and documents live in the patient's own
/// portal; Rumi complements it and Rumi Works operates those features there.
enum CareDestination: Hashable {
    case appointments
    case appointmentDetail(UUID)
    case trip(UUID)
    case carePlan
    case medications
    case records
    case visitPrep
    case reports
    case connections
}

// MARK: - Appointment enrichment (§4.4.2 / §4.4.3)

enum AppointmentKind: String, Codable {
    case inPerson
    case telehealth

    var label: String { self == .telehealth ? "Telehealth" : "In person" }
    var glyph: String { self == .telehealth ? "video" : "building.2" }
}

enum AppointmentStatus: String, Codable {
    case confirmed, pending, cancelled

    var label: String {
        switch self {
        case .confirmed: return "Confirmed"
        case .pending: return "Pending"
        case .cancelled: return "Cancelled"
        }
    }
}

/// One step in a trip plan — gets the user to the visit without friction.
struct TripStep: Identifiable, Equatable {
    let id = UUID()
    let glyph: String
    let title: String
    let detail: String
}

/// The wayfinding "trip plan" (§4.4.3) — depart-by, route, and the pre-visit
/// checklist; or a readiness flow for a telehealth visit.
struct TripPlan: Equatable {
    let departBy: Date
    let travelMinutes: Int
    let routeHint: String
    let destinationDetail: String
    let mapQuery: String
    let checklist: [String]
    var isVirtual: Bool = false
    /// A known calendar conflict to surface before it bites (WAY-3).
    var calendarConflict: String? = nil
    /// Whether a ride can be offered (WAY-4).
    var rideHint: String? = nil
}

// MARK: - Looking-ahead (population risk · §4.10)

/// The only patient-facing expression of the prediction model: a population-
/// level, screening-and-prevention nudge that routes to care. Never an
/// individual prediction, probability, or date (PRD-1/2). Suppressed by
/// opt-out, crisis, and the first 14 days (PRD-5/6).
struct LookingAheadNudge: Equatable {
    let headline: String
    let body: String
    /// "why am I seeing this" — the population basis, made honest (PRD-4).
    let basis: String
    /// The guide question this routes into (PRD-3).
    let guideQuestion: String
}

// MARK: - Needs you (the Care/Today attention band · §3.2, §4.3 TDY-3)

struct NeedsYouItem: Identifiable, Equatable {
    enum Kind {
        case result, appointment

        var glyph: String {
            switch self {
            case .result: return "drop"
            case .appointment: return "calendar"
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let detail: String
    let destination: CareDestination
}
