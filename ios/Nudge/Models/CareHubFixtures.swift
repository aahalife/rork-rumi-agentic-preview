import Foundation

/// The Care hub fixture corpus (§7.4) — production-shaped clinical data for all
/// three pathways, so Care is fully navigable and never a dead-end for Marcus,
/// Elena, or Sam. One bundle re-seeds every Care surface when the pathway
/// changes, exactly like the rest of the persona spine.
struct CareBundle {
    let appointments: [Appointment]
    /// A new significant result the user hasn't acknowledged yet (REC-5).
    let resultToAck: (title: String, detail: String, series: String?)?
    /// Population-level, route-to-care nudge — nil where it would be unkind
    /// (mid-treatment) or forced (§4.10).
    let lookingAhead: LookingAheadNudge?
}

enum CareHubFixtures {
    static func bundle(for pathway: CarePathway) -> CareBundle {
        switch pathway {
        case .metabolic: return marcus
        case .oncology: return elena
        case .procedure: return sam
        case .cardiometabolic: return rosa
        }
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 10, _ min: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        return Calendar.current.date(from: c) ?? .now
    }

    private static func hoursAgo(_ h: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: -h, to: .now) ?? .now
    }

    private static func departBy(_ appt: Date, travel: Int, buffer: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: -(travel + buffer), to: appt) ?? appt
    }

    // MARK: - Marcus · metabolic (T2D · HTN · CKD-2)

    static let marcus: CareBundle = {
        let pattersonVisit = date(2026, 6, 24, 10, 30)
        let nephTelehealth = date(2026, 7, 1, 14, 0)


        let appointments: [Appointment] = [
            Appointment(
                with: "Dr. Alicia Patterson", date: pattersonVisit,
                location: "Piedmont Internal Medicine", prepReady: true,
                kind: .inPerson, status: .confirmed, joinLink: nil,
                trip: TripPlan(
                    departBy: departBy(pattersonVisit, travel: 18, buffer: 20),
                    travelMinutes: 18,
                    routeHint: "18 min drive · usually light mid-morning",
                    destinationDetail: "Piedmont Internal Medicine · 3rd floor, Suite 320 · Lot B parking",
                    mapQuery: "Piedmont Internal Medicine Atlanta",
                    checklist: ["Insurance card", "Home BP cuff readings — I'll have them charted", "The atorvastatin-timing question"],
                    rideHint: "It's a short drive, but I can line up a ride if the truck's acting up."
                ),
                planGoalHint: "Reviews your A1c trend and the home-BP goal"
            ),
            Appointment(
                with: "Dr. Samuel Okafor · Nephrology", date: nephTelehealth,
                location: "Telehealth · Emory video visit", prepReady: false,
                kind: .telehealth, status: .confirmed,
                joinLink: "https://emory.example/visit/marcus",
                trip: TripPlan(
                    departBy: nephTelehealth,
                    travelMinutes: 0,
                    routeHint: "Join from home",
                    destinationDetail: "Emory video visit",
                    mapQuery: "",
                    checklist: ["A quiet spot with good signal", "Your latest home BP readings", "Any questions about the kidney panel"],
                    isVirtual: true
                ),
                planGoalHint: "Checks in on kidney protection"
            ),
        ]






        return CareBundle(
            appointments: appointments,
            resultToAck: ("A1c — 8.4%", "Down from 8.7 in December — fifth drop in a row.", "a1c"),
            lookingAhead: LookingAheadNudge(
                headline: "A screening worth a conversation",
                body: "People managing diabetes for several years sometimes benefit from a kidney-protection medication review. It may be worth asking Dr. Patterson whether it fits you.",
                basis: "This is a general, population-level suggestion based on living with type 2 diabetes — not a prediction about you, and no number or date is implied.",
                guideQuestion: "Is there a kidney-protective medication (like an SGLT2) worth considering for me?"
            )
        )
    }()

    // MARK: - Elena · oncology (breast cancer · AC-T · cycle 3 of 6)

    static let elena: CareBundle = {
        let cycle4 = date(2026, 6, 22, 9, 0)
        let riveraVisit = date(2026, 7, 6, 11, 0)
        let navigatorCheck = date(2026, 6, 18, 15, 0)


        let appointments: [Appointment] = [
            Appointment(
                with: "Cycle 4 infusion · Dr. Rivera's team", date: cycle4,
                location: "Northside Infusion Center", prepReady: true,
                kind: .inPerson, status: .confirmed,
                trip: TripPlan(
                    departBy: departBy(cycle4, travel: 25, buffer: 30),
                    travelMinutes: 25,
                    routeHint: "25 min drive · leave a buffer, infusion days run long",
                    destinationDetail: "Northside Infusion Center · 2nd floor · valet available at the main entrance",
                    mapQuery: "Northside Infusion Center Atlanta",
                    checklist: ["Insurance card", "A warm layer — infusion rooms run cold", "Something to pass the time (3–4 hrs)", "Pre-meds taken this morning", "A driver for the way home"],
                    rideHint: "You shouldn't drive yourself home after infusion — want me to help arrange a ride?"
                ),
                planGoalHint: "Cycle 4 of 6 — anti-nausea plan carried over from cycle 3"
            ),
            Appointment(
                with: "Nia Coleman, RN · symptom check", date: navigatorCheck,
                location: "Telehealth · Northside video visit", prepReady: false,
                kind: .telehealth, status: .confirmed,
                joinLink: "https://northside.example/visit/elena",
                trip: TripPlan(
                    departBy: navigatorCheck,
                    travelMinutes: 0, routeHint: "Join from home",
                    destinationDetail: "Northside video visit",
                    mapQuery: "",
                    checklist: ["Your symptom log this cycle", "The tingling notes since cycle 2", "A quiet, well-lit spot"],
                    isVirtual: true
                ),
                planGoalHint: "Checks the low-count window plan with you"
            ),
            Appointment(
                with: "Dr. Maya Rivera", date: riveraVisit,
                location: "Northside Cancer Institute", prepReady: false,
                kind: .inPerson, status: .confirmed,
                planGoalHint: "Mid-treatment review"
            ),
        ]






        return CareBundle(
            appointments: appointments,
            resultToAck: ("Counts recovered — ANC 1.7", "Right on time, third cycle running.", "anc"),
            lookingAhead: nil   // mid-treatment: looking-ahead nudges are unkind here (§4.10)
        )
    }()

    // MARK: - Sam · procedure (knee replacement · 12 days out)

    static let sam: CareBundle = {
        let preOp = date(2026, 6, 17, 9, 0)
        let surgery = date(2026, 6, 23, 6, 30)
        let ptConsult = date(2026, 6, 19, 13, 0)


        let appointments: [Appointment] = [
            Appointment(
                with: "Pre-op visit · Dr. Chen", date: preOp,
                location: "Midtown Orthopedics", prepReady: true,
                kind: .inPerson, status: .confirmed,
                trip: TripPlan(
                    departBy: departBy(preOp, travel: 22, buffer: 20),
                    travelMinutes: 22,
                    routeHint: "22 min drive · morning traffic, leave a cushion",
                    destinationDetail: "Midtown Orthopedics · 5th floor · garage on Peachtree, validated",
                    mapQuery: "Midtown Orthopedics Atlanta",
                    checklist: ["Insurance card", "Full med + supplement list (for anesthesia)", "The NSAID-timing question", "Surgical packet"],
                    rideHint: nil
                ),
                planGoalHint: "Clears you for surgery and confirms the NSAID stop"
            ),
            Appointment(
                with: "Surgery · knee replacement", date: surgery,
                location: "Midtown Surgical Center · arrive 6:30am", prepReady: true,
                kind: .inPerson, status: .confirmed,
                trip: TripPlan(
                    departBy: departBy(surgery, travel: 22, buffer: 40),
                    travelMinutes: 22,
                    routeHint: "22 min drive · pre-dawn, roads clear",
                    destinationDetail: "Midtown Surgical Center · Surgical check-in, 1st floor",
                    mapQuery: "Midtown Surgical Center Atlanta",
                    checklist: ["Nothing to eat after midnight", "ID + insurance card", "Loose shorts, slip-on shoes", "Phone charger", "Ride home confirmed"],
                    calendarConflict: "Heads up — your calendar shows a 5pm work call on the 23rd. You'll still be recovering. Want me to help you move it?",
                    rideHint: "You'll need a driver home from this one — let's make sure that's locked in."
                ),
                planGoalHint: "The main event — walking in strong pays off twice"
            ),
            Appointment(
                with: "Priya Nair, PT · pre-surgery consult", date: ptConsult,
                location: "Telehealth · Midtown Rehab video", prepReady: false,
                kind: .telehealth, status: .pending,
                joinLink: "https://midtownrehab.example/visit/sam",
                trip: TripPlan(
                    departBy: ptConsult,
                    travelMinutes: 0, routeHint: "Join from home",
                    destinationDetail: "Midtown Rehab video visit",
                    mapQuery: "",
                    checklist: ["A clear space to show your range of motion", "Your prehab questions"],
                    isVirtual: true
                ),
                planGoalHint: "Sets up week-one recovery expectations"
            ),
        ]






        return CareBundle(
            appointments: appointments,
            resultToAck: ("MRI confirmed — bone-on-bone", "The answer to three years of grinding.", nil),
            lookingAhead: nil   // peri-procedure: keep the focus on the surgery (§4.10)
        )
    }()

    // MARK: - Rosa · cardiometabolic (T2D + heart failure + CKD risk)

    static let rosa: CareBundle = {
        let cardiologyVisit = date(2026, 6, 26, 10, 30)
        let nephTelehealth = date(2026, 7, 2, 14, 0)
        let primaryVisit = date(2026, 7, 9, 9, 30)


        let appointments: [Appointment] = [
            Appointment(
                with: "Dr. Lena Reyes · Cardiology", date: cardiologyVisit,
                location: "Emory Heart & Vascular", prepReady: true,
                kind: .inPerson, status: .confirmed, joinLink: nil,
                trip: TripPlan(
                    departBy: departBy(cardiologyVisit, travel: 20, buffer: 20),
                    travelMinutes: 20,
                    routeHint: "20 min drive · usually light mid-morning",
                    destinationDetail: "Emory Heart & Vascular · 4th floor · deck parking, validated",
                    mapQuery: "Emory Heart and Vascular Atlanta",
                    checklist: ["Insurance card", "Your daily-weight log — I'll have it charted", "Home BP readings", "The furosemide-dose question"],
                    rideHint: nil
                ),
                planGoalHint: "Reviews your weight trend and the fluid plan"
            ),
            Appointment(
                with: "Dr. Samuel Okafor · Nephrology", date: nephTelehealth,
                location: "Telehealth · Emory video visit", prepReady: false,
                kind: .telehealth, status: .confirmed,
                joinLink: "https://emory.example/visit/rosa",
                trip: TripPlan(
                    departBy: nephTelehealth,
                    travelMinutes: 0, routeHint: "Join from home",
                    destinationDetail: "Emory video visit",
                    mapQuery: "",
                    checklist: ["A quiet spot with good signal", "Your latest eGFR question", "The sodium-and-fluid notes"],
                    isVirtual: true
                ),
                planGoalHint: "Checks kidney protection and the eGFR trend"
            ),
            Appointment(
                with: "Dr. Anita Shah · Primary care", date: primaryVisit,
                location: "Piedmont Internal Medicine", prepReady: false,
                kind: .inPerson, status: .pending,
                planGoalHint: "Reconciles all three teams into one plan"
            ),
        ]






        return CareBundle(
            appointments: appointments,
            resultToAck: ("eGFR 66 — holding steady", "Kidneys steady; the protection is working.", "egfr"),
            lookingAhead: LookingAheadNudge(
                headline: "Keeping your three teams in step",
                body: "When diabetes, heart and kidney care overlap, people sometimes benefit from their specialists comparing notes directly. It may be worth asking whether your next eGFR can be reviewed by both cardiology and nephrology.",
                basis: "This is a general suggestion drawn from managing several overlapping conditions — not a prediction about you, and no number or date is implied.",
                guideQuestion: "Can cardiology and nephrology coordinate on my next kidney panel?"
            )
        )
    }()
}
