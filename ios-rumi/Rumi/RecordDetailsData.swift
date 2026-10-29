//
//  RecordDetailsData.swift
//  Rumi
//
//  Content for the Tier 3 record detail screens (one example per category).
//

import Foundation

enum RecordDetailID: Hashable {
    case lab, vital, condition, allergy, immunization, procedure, carePlan
    case medication, diagnosticReport, imaging, document, form, pendingOrder
    case visit, coverage, claim
}

/// Where a field value links to.
enum DetailLink: Hashable {
    /// Opens another detail screen.
    case record(RecordDetailID)
    /// Linked record that has no detail screen yet; shown as tappable.
    case unavailable
}

struct DetailField: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var note: String? = nil
    var link: DetailLink? = nil
}

struct DetailSection: Identifiable {
    let id = UUID()
    let title: String
    /// Optional introductory line shown at the top of the card.
    var intro: String? = nil
    let fields: [DetailField]
}

struct RecordDetail {
    let title: String
    let subtitle: String
    let sections: [DetailSection]
    var showsPatientFooter = true
}

private func f(_ label: String, _ value: String, note: String? = nil, link: DetailLink? = nil) -> DetailField {
    DetailField(label: label, value: value, note: note, link: link)
}

enum RecordDetails {
    static let patientLine = "Alex Morgan · Born May 14, 1986"
    static let sourceLine = "Fictional example · Imported health record"

    static func detail(_ id: RecordDetailID) -> RecordDetail {
        switch id {
        case .lab: lab
        case .vital: vital
        case .condition: condition
        case .allergy: allergy
        case .immunization: immunization
        case .procedure: procedure
        case .carePlan: carePlan
        case .medication: medication
        case .diagnosticReport: diagnosticReport
        case .imaging: imaging
        case .document: document
        case .form: form
        case .pendingOrder: pendingOrder
        case .visit: visit
        case .coverage: coverage
        case .claim: claim
        }
    }

    private static let primaryCareEncounter = "Primary care follow-up\nOct 12, 2026 · Dr. Maya Chen"

    // MARK: Lab

    private static let lab = RecordDetail(
        title: "Hemoglobin A1c",
        subtitle: "Collected October 12, 2026 · Harbor Laboratory",
        sections: [
            DetailSection(title: "Result", fields: [
                f("Test name", "Hemoglobin A1c"),
                f("Value", "6.8"),
                f("Unit", "%"),
                f("Reference range", "4.0–5.6%"),
                f("Abnormal flag", "High (H)"),
            ]),
            DetailSection(title: "Timing", fields: [
                f("Collection date", "October 12, 2026 at 8:15 AM"),
                f("Result released", "October 12, 2026 at 2:40 PM"),
            ]),
            DetailSection(title: "Specimen and method", fields: [
                f("Specimen", "Whole blood · EDTA tube"),
                f("Method", "High-performance liquid chromatography (HPLC)"),
            ]),
            DetailSection(title: "Related results", fields: [
                f("Hemoglobin A1c", "6.8% · High"),
                f("Estimated average glucose", "148 mg/dL · Calculated"),
            ]),
            DetailSection(title: "Source and care", fields: [
                f("Source", "Harbor Health · Patient portal"),
                f("Performer", "Rita Wong, CLS / Harbor Laboratory"),
                f("Encounter", primaryCareEncounter, link: .record(.visit)),
            ]),
            DetailSection(title: "Notes", fields: [
                f("Laboratory note", "A1c reflects average glucose over approximately 3 months. Results may be affected by altered red blood cell turnover."),
                f("Clinician note", "Improved from 7.2% on April 8, 2026. Continue the current treatment plan; repeat in 3 months."),
            ]),
        ],
        showsPatientFooter: false
    )

    // MARK: Vital

    private static let vital = RecordDetail(
        title: "Blood pressure",
        subtitle: "Measured October 12, 2026 · Harbor Primary Care",
        sections: [
            DetailSection(title: "Measurement", fields: [
                f("Measurement name", "Blood pressure panel"),
                f("Value", "128/78"),
                f("Unit", "mmHg"),
                f("Reference range", "Systolic: 90–129 mmHg\nDiastolic: 60–79 mmHg"),
                f("Abnormal flag", "None reported"),
            ]),
            DetailSection(title: "Timing", fields: [
                f("Collection date", "October 12, 2026 at 8:32 AM"),
                f("Result released", "October 12, 2026 at 8:35 AM"),
            ]),
            DetailSection(title: "Method", fields: [
                f("Specimen", "Not applicable · Noninvasive measurement"),
                f("Method", "Automated oscillometric cuff\nLeft upper arm · Seated"),
                f("Measurement conditions", "Adult cuff · After 5 minutes of rest"),
            ]),
            DetailSection(title: "Sub-results", fields: [
                f("Systolic blood pressure", "128 mmHg"),
                f("Diastolic blood pressure", "78 mmHg"),
                f("Mean arterial pressure", "95 mmHg · Calculated"),
            ]),
            DetailSection(title: "Source and care", fields: [
                f("Source", "Harbor Health · Clinical record"),
                f("Performer", "Avery Davis, MA / Harbor Primary Care"),
                f("Encounter", primaryCareEncounter, link: .record(.visit)),
            ]),
            DetailSection(title: "Notes", fields: [
                f("Clinical note", "Patient seated with feet flat and arm supported at heart level. No symptoms reported during measurement."),
            ]),
        ],
        showsPatientFooter: false
    )

    // MARK: Condition

    private static let condition = RecordDetail(
        title: "Type 2 diabetes mellitus",
        subtitle: "Recorded October 12, 2026 · Harbor Health",
        sections: [
            DetailSection(title: "Condition", fields: [
                f("Condition name", "Type 2 diabetes mellitus, without complications"),
                f("Clinical status", "Active"),
                f("Verification status", "Confirmed"),
                f("Severity", "Mild"),
            ]),
            DetailSection(title: "History", fields: [
                f("Onset date", "November 14, 2025"),
                f("Resolution date", "Not resolved"),
                f("Date recorded", "October 12, 2026"),
                f("Record type", "Problem-list condition"),
            ]),
            DetailSection(title: "Care team", fields: [
                f("Recorder", "Dr. Maya Chen · Primary care"),
                f("Asserter", "Dr. Maya Chen"),
                f("Encounter", "Primary care follow-up\nOctober 12, 2026", link: .record(.visit)),
            ]),
        ]
    )

    // MARK: Allergy

    private static let allergy = RecordDetail(
        title: "Penicillin",
        subtitle: "Reviewed October 12, 2026 · Harbor Primary Care",
        sections: [
            DetailSection(title: "Allergy", fields: [
                f("Allergen", "Penicillin · Antibiotic"),
                f("Clinical status", "Active"),
                f("Verification status", "Confirmed"),
                f("Criticality", "High · Risk of a serious reaction"),
            ]),
            DetailSection(title: "Reaction", fields: [
                f("Symptoms", "Generalized hives, lip swelling and difficulty breathing"),
                f("Reaction severity", "Severe"),
                f("Onset date", "June 3, 2004"),
                f("Exposure route", "Oral"),
            ]),
            DetailSection(title: "Record information", fields: [
                f("Recorder", "Dr. Maya Chen"),
                f("Recorded", "October 12, 2026"),
                f("Source", "Patient report; prior emergency treatment documented in transferred records."),
            ]),
        ]
    )

    // MARK: Immunization

    private static let immunization = RecordDetail(
        title: "Influenza vaccine",
        subtitle: "Given October 12, 2026 · Harbor Primary Care",
        sections: [
            DetailSection(title: "Vaccine", fields: [
                f("Vaccine product", "Influenza, trivalent, preservative-free\nFluarix · 2026–2027 season"),
                f("Status", "Completed"),
                f("Date given", "October 12, 2026 at 9:05 AM"),
                f("Dose number/series length", "Dose 1 of 1 · Annual vaccination"),
            ]),
            DetailSection(title: "Administration", fields: [
                f("Dose", "0.5 mL"),
                f("Body site", "Left deltoid"),
                f("Route", "Intramuscular"),
                f("Administrator", "Taylor Reed, RN"),
                f("Lot number", "F26X104 · Fictional lot"),
            ]),
            DetailSection(title: "Reaction", fields: [
                f("Immediate reaction", "None observed"),
                f("Observation", "Observed for 15 minutes after administration. No adverse symptoms reported."),
            ]),
        ]
    )

    // MARK: Procedure

    private static let procedure = RecordDetail(
        title: "Venipuncture",
        subtitle: "October 12, 2026 · Harbor Laboratory",
        sections: [
            DetailSection(title: "Procedure", fields: [
                f("Procedure name", "Venous blood collection"),
                f("Status", "Completed"),
                f("Date/period", "October 12, 2026\n8:15–8:20 AM"),
                f("Body site", "Left antecubital vein"),
            ]),
            DetailSection(title: "Performer", fields: [
                f("Performer and role", "Rita Wong, CLS\nClinical laboratory scientist"),
                f("Organization", "Harbor Laboratory"),
            ]),
            DetailSection(title: "Clinical information", fields: [
                f("Reason", "Type 2 diabetes monitoring and lipid assessment"),
                f("Outcome", "Blood samples collected successfully on first attempt"),
                f("Complications", "None documented"),
                f("Follow-up", "Remove dressing after 30 minutes. Contact the clinic for persistent bleeding, redness or swelling."),
            ]),
            DetailSection(title: "Related report", fields: [
                f("Linked report", "Diabetes monitoring panel\nOctober 12, 2026 · Final", link: .record(.diagnosticReport)),
            ]),
        ]
    )

    // MARK: Care plan

    private static let carePlan = RecordDetail(
        title: "Diabetes self-management",
        subtitle: "Active plan · Dr. Maya Chen",
        sections: [
            DetailSection(title: "Plan", fields: [
                f("Title", "Diabetes self-management"),
                f("Category", "Chronic condition management"),
                f("Status", "Active"),
                f("Intent", "Plan"),
                f("Start date", "October 12, 2026"),
                f("End date", "January 12, 2027"),
            ]),
            DetailSection(title: "Activities", fields: [
                f("Medication routine", "Take metformin ER 500 mg once daily with the evening meal. Review tolerance at the next visit."),
                f("Movement", "Aim for 150 minutes of moderate activity per week, adjusted for knee symptoms."),
                f("Nutrition", "Follow the individualized nutrition plan reviewed with Elena Ruiz, RD."),
                f("Monitoring", "Repeat hemoglobin A1c in January 2027. Bring glucose readings and questions to follow-up."),
            ]),
            DetailSection(title: "Linked goals", fields: [
                f("A1c goal", "Maintain hemoglobin A1c below 7.0%\nTarget review: January 12, 2027", link: .unavailable),
                f("Activity goal", "Build toward 30 minutes of movement on 5 days each week.", link: .unavailable),
            ]),
            DetailSection(title: "Linked care team", fields: [
                f("Primary care", "Dr. Maya Chen · Harbor Primary Care", link: .unavailable),
                f("Nutrition", "Elena Ruiz, RD · Harbor Nutrition", link: .unavailable),
                f("Patient", "Alex Morgan · Self-management partner"),
            ]),
        ]
    )

    // MARK: Medication

    private static let medication = RecordDetail(
        title: "Metformin ER 500 mg",
        subtitle: "Active prescription · Written October 12, 2026",
        sections: [
            DetailSection(title: "Prescription", fields: [
                f("Drug name", "Metformin hydrochloride 500 mg\nExtended-release tablet"),
                f("Status", "Active"),
                f("Intent", "Order"),
                f("Directions", "Take 1 tablet by mouth once daily with the evening meal. Swallow whole."),
                f("Reason", "Type 2 diabetes mellitus", link: .record(.condition)),
            ]),
            DetailSection(title: "Prescribing team", fields: [
                f("Prescriber", "Dr. Maya Chen"),
                f("Recorder", "Dr. Maya Chen"),
                f("Pharmacy", "Harbor Community Pharmacy\n120 Bay Street, Portland, OR"),
            ]),
            DetailSection(title: "Dispensing", fields: [
                f("Date written", "October 12, 2026"),
                f("Refills", "2 authorized"),
                f("Quantity", "90 tablets"),
                f("Days supply", "90 days"),
                f("Validity period", "October 12, 2026–October 11, 2027"),
                f("Substitution allowed", "Yes · Generic substitution permitted"),
            ]),
        ]
    )

    // MARK: Diagnostic report

    private static let diagnosticReport = RecordDetail(
        title: "Diabetes monitoring panel",
        subtitle: "Final report · Harbor Laboratory",
        sections: [
            DetailSection(title: "Report", fields: [
                f("Report name", "Diabetes monitoring panel"),
                f("Status", "Final"),
                f("Effective date", "October 12, 2026 at 8:15 AM"),
                f("Issued date", "October 12, 2026 at 2:40 PM"),
                f("Performer", "Harbor Laboratory\nRita Wong, CLS"),
            ]),
            DetailSection(title: "Linked lab results", fields: [
                f("Hemoglobin A1c", "6.8% · High\nOctober 12, 2026", link: .record(.lab)),
                f("Comprehensive metabolic panel", "Glucose 118 mg/dL · High\nOctober 12, 2026", link: .unavailable),
                f("Urine albumin/creatinine", "12 mg/g · Within reference range\nOctober 12, 2026", link: .unavailable),
            ]),
            DetailSection(title: "Conclusion", fields: [
                f("Laboratory conclusion", "Hemoglobin A1c remains above the laboratory reference range and has improved since April 2026. Urine albumin/creatinine is within the reference range. Review results with the ordering clinician."),
            ]),
            DetailSection(title: "Attachment", fields: [
                f("Attached report file", "Diabetes-monitoring-2026-10-12.pdf",
                  note: "PDF document · 3 pages · 248 KB", link: .unavailable),
            ]),
        ]
    )

    // MARK: Imaging

    private static let imaging = RecordDetail(
        title: "MRI · Right knee",
        subtitle: "September 22, 2026 · Summit Imaging",
        sections: [
            DetailSection(title: "Study", fields: [
                f("Modality", "Magnetic resonance imaging (MR)\nWithout contrast"),
                f("Body site", "Knee joint"),
                f("Laterality", "Right"),
                f("Date", "September 22, 2026 at 10:00 AM"),
                f("Status", "Available"),
                f("Series/image counts", "6 series · 182 images"),
            ]),
            DetailSection(title: "Clinical information", fields: [
                f("Referring provider", "Dr. Samir Patel\nSummit Orthopedics"),
                f("Reason", "Persistent right knee pain and swelling after activity. Evaluate for internal derangement."),
                f("Interpreter", "Dr. Grace Kim · Radiologist"),
            ]),
            DetailSection(title: "Linked records", fields: [
                f("Linked order", "MRI right knee without contrast\nOrdered September 18, 2026", link: .unavailable),
                f("Image retrieval link", "View 182 images", note: "Opens Summit Imaging viewer", link: .unavailable),
            ]),
            DetailSection(title: "Interpretation", fields: [
                f("Impression", "Mild patellofemoral chondral thinning with a small joint effusion. No meniscal tear or acute ligament injury."),
            ]),
        ]
    )

    // MARK: Document

    private static let document = RecordDetail(
        title: "After-visit summary",
        subtitle: "October 12, 2026 · Dr. Maya Chen",
        sections: [
            DetailSection(title: "Document", fields: [
                f("Document type", "After-visit summary"),
                f("Description", "Summary of diabetes follow-up, medication review, immunizations and next steps from the October 12 primary care visit."),
                f("Date", "October 12, 2026 at 9:20 AM"),
                f("Author", "Dr. Maya Chen\nHarbor Primary Care"),
            ]),
            DetailSection(title: "Status and format", fields: [
                f("Reference status", "Current"),
                f("Document status", "Final · Signed"),
                f("Format", "application/pdf · 3 pages · 182 KB"),
            ]),
            DetailSection(title: "Content", fields: [
                f("Content link", "Open after-visit summary",
                  note: "AVS-Alex-Morgan-2026-10-12.pdf", link: .unavailable),
            ]),
        ]
    )

    // MARK: Form

    private static let form = RecordDetail(
        title: "PHQ-2 depression screening",
        subtitle: "Completed October 12, 2026 · Final response",
        sections: [
            DetailSection(title: "Questionnaire", fields: [
                f("Questionnaire name", "Patient Health Questionnaire-2 (PHQ-2)"),
                f("Status", "Completed · Final"),
                f("Date authored", "October 12, 2026 at 8:10 AM"),
                f("Author", "Avery Davis, MA · Recorded the questionnaire response"),
                f("Source", "Alex Morgan · Patient-reported answers"),
                f("Linked visit", "Primary care follow-up\nOctober 12, 2026 · Dr. Maya Chen", link: .record(.visit)),
            ]),
            DetailSection(
                title: "Questions and answers",
                intro: "Over the last 2 weeks, how often have you been bothered by the following problems?",
                fields: [
                    f("Little interest or pleasure in doing things", "Not at all · 0"),
                    f("Feeling down, depressed, or hopeless", "Not at all · 0"),
                ]
            ),
            DetailSection(title: "Screening result", fields: [
                f("Total score", "0 out of 6"),
                f("Interpretation", "Negative screen at this visit. This questionnaire is a screening tool and does not establish a diagnosis."),
            ]),
        ]
    )

    // MARK: Pending order

    private static let pendingOrder = RecordDetail(
        title: "Hemoglobin A1c",
        subtitle: "Illustrative populated state · Not part of Home's current 0 orders",
        sections: [
            DetailSection(title: "Order", fields: [
                f("Requested item", "Hemoglobin A1c\nVenous blood specimen"),
                f("Status", "Scheduled"),
                f("Intent", "Order"),
                f("Priority", "Routine"),
            ]),
            DetailSection(title: "Scheduling", fields: [
                f("Authored date", "October 12, 2026 at 9:12 AM"),
                f("Scheduled occurrence", "January 12, 2027 at 8:00 AM\nHarbor Laboratory"),
            ]),
            DetailSection(title: "Clinical information", fields: [
                f("Requester", "Dr. Maya Chen\nHarbor Primary Care"),
                f("Reason", "Monitor response to diabetes self-management plan and metformin. Repeat 3 months after the October result of 6.8%."),
            ]),
        ]
    )

    // MARK: Visit

    private static let visit = RecordDetail(
        title: "Primary care follow-up",
        subtitle: "October 12, 2026 · Dr. Maya Chen",
        sections: [
            DetailSection(title: "Visit", fields: [
                f("Setting", "Ambulatory · In-person office visit"),
                f("Status", "Finished"),
                f("Reason", "Type 2 diabetes follow-up, lipid review and seasonal immunizations"),
                f("Service category", "Primary care · Chronic disease management"),
            ]),
            DetailSection(title: "Time and place", fields: [
                f("Start time", "October 12, 2026 at 8:30 AM PDT"),
                f("End time", "October 12, 2026 at 9:15 AM PDT"),
                f("Location", "Harbor Primary Care\n120 Bay Street, Suite 200\nPortland, OR 97205"),
            ]),
            DetailSection(title: "Providers", fields: [
                f("Attending provider", "Dr. Maya Chen · Family medicine"),
                f("Nursing", "Taylor Reed, RN"),
                f("Rooming and measurements", "Avery Davis, MA"),
            ]),
        ]
    )

    // MARK: Coverage

    private static let coverage = RecordDetail(
        title: "Evergreen Health PPO",
        subtitle: "2026 coverage · Alex Morgan",
        sections: [
            DetailSection(title: "Coverage", fields: [
                f("Status", "Active"),
                f("Type", "Preferred Provider Organization (PPO)"),
                f("Payer", "Evergreen Health\nFictional insurance company"),
                f("Priority", "1 · Primary coverage"),
            ]),
            DetailSection(title: "Member information", fields: [
                f("Subscriber", "Alex Morgan"),
                f("Subscriber ID", "EVG-00482716"),
                f("Beneficiary", "Alex Morgan"),
                f("Relationship", "Self"),
            ]),
            DetailSection(title: "Effective dates", fields: [
                f("Start date", "January 1, 2026"),
                f("End date", "December 31, 2026"),
            ]),
            DetailSection(title: "Plan identifiers", fields: [
                f("Plan name", "Evergreen Choice PPO"),
                f("Plan ID", "ECP-2026-OR"),
                f("Group number", "GRP-4827"),
                f("Group name", "North Coast Design Cooperative"),
            ]),
        ]
    )

    // MARK: Claim

    private static let claim = RecordDetail(
        title: "Harbor Primary Care",
        subtitle: "Service October 12, 2026 · Claim CLM-261012-0482",
        sections: [
            DetailSection(title: "Claim", fields: [
                f("Status", "Active · Paid"),
                f("Claim type", "Professional · Original claim"),
                f("Patient", "Alex Morgan\nBorn May 14, 1986"),
                f("Billing provider", "Harbor Primary Care\nDr. Maya Chen"),
                f("Billed period", "October 12, 2026\n8:30–9:15 AM"),
            ]),
            DetailSection(title: "Insurance and payment", fields: [
                f("Insurer", "Evergreen Health · Choice PPO", link: .record(.coverage)),
                f("Payee", "Harbor Primary Care · Payment to provider"),
                f("Outcome", "Complete · Adjudicated October 15, 2026"),
                f("Patient responsibility", "$42.00 · Coinsurance"),
            ]),
            DetailSection(title: "Linked diagnoses", fields: [
                f("Primary diagnosis", "Type 2 diabetes mellitus\nE11.9 · Without complications", link: .record(.condition)),
                f("Secondary diagnosis", "Hyperlipidemia\nE78.5", link: .unavailable),
            ]),
            DetailSection(title: "Linked procedures", fields: [
                f("Office visit", "Established patient visit · 99214", link: .record(.visit)),
                f("Blood collection", "Venipuncture · 36415", link: .record(.procedure)),
            ]),
            DetailSection(title: "Itemized service lines", fields: [
                f("99214 · Office visit",
                  "October 12, 2026\nQuantity 1\nBilled $250.00\nAdjudicated allowed $190.00\nInsurer paid $152.00\nPatient coinsurance $38.00"),
                f("36415 · Venipuncture",
                  "October 12, 2026\nQuantity 1\nBilled $35.00\nAdjudicated allowed $20.00\nInsurer paid $16.00\nPatient coinsurance $4.00"),
            ]),
            DetailSection(title: "Totals", fields: [
                f("Total billed", "$285.00"),
                f("Total adjudicated allowed", "$210.00"),
                f("Contractual adjustment", "$75.00 · Not owed by patient"),
                f("Total insurer payment", "$168.00"),
                f("Total patient responsibility", "$42.00"),
                f("Claim note", "This is not a bill. Amounts reflect the insurer's explanation of benefits. Contact Evergreen Health with questions about adjudication or coverage."),
            ]),
        ]
    )
}
