//
//  HealthRecordsData.swift
//  Rumi
//
//  Sample record content for each Health category list (most recent first).
//

import Foundation

struct HealthItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case standard
        case coverage
        case claim
    }

    let id = UUID()
    let primary: String
    let secondary: String
    var kind: Kind = .standard
    /// Detail screen this row opens, if one has been built.
    var detail: RecordDetailID?

    init(_ primary: String, _ secondary: String, kind: Kind = .standard, detail: RecordDetailID? = nil) {
        self.primary = primary
        self.secondary = secondary
        self.kind = kind
        // Coverage and Claim rows each open their own dedicated layout.
        switch kind {
        case .coverage: self.detail = .coverage
        case .claim: self.detail = .claim
        case .standard: self.detail = detail
        }
    }
}

enum HealthRecordsData {
    static func items(for title: String) -> [HealthItem] {
        all[title] ?? []
    }

    private static let all: [String: [HealthItem]] = [
        "Labs": [
            .init("Hemoglobin A1c", "6.8% · Oct 12 2026 · High", detail: .lab),
            .init("Lipid panel", "LDL 132 mg/dL · Oct 12 2026 · High"),
            .init("Comprehensive metabolic panel", "Glucose 118 mg/dL · Oct 12 2026 · High"),
            .init("Urine albumin/creatinine", "12 mg/g · Oct 12 2026"),
            .init("Thyroid-stimulating hormone", "2.1 mIU/L · Jul 10 2026"),
            .init("Complete blood count", "Hemoglobin 13.8 g/dL · Jul 10 2026"),
            .init("Vitamin D, 25-hydroxy", "34 ng/mL · Apr 8 2026"),
            .init("Hemoglobin A1c", "7.2% · Apr 8 2026 · High"),
        ],
        "Vitals": [
            .init("Blood pressure", "128/78 mmHg · Oct 12 2026", detail: .vital),
            .init("Heart rate", "72 beats/min · Oct 12 2026"),
            .init("Weight", "78.4 kg · Oct 12 2026"),
            .init("Body mass index", "26.2 kg/m² · Oct 12 2026"),
            .init("Oxygen saturation", "98% · Oct 12 2026"),
            .init("Temperature", "36.8°C · Sep 18 2026"),
            .init("Respiratory rate", "16 breaths/min · Sep 18 2026"),
            .init("Height", "173 cm · Apr 8 2026"),
        ],
        "Conditions": [
            .init("Type 2 diabetes mellitus", "Active · Recorded Oct 12 2026", detail: .condition),
            .init("Hyperlipidemia", "Active · Recorded Oct 12 2026"),
            .init("Right knee pain", "Active · Recorded Sep 18 2026"),
            .init("Seasonal allergic rhinitis", "Active · Recorded Jul 10 2026"),
            .init("Vitamin D deficiency", "Resolved · Recorded Apr 8 2026"),
            .init("Migraine without aura", "Active · Recorded Feb 2 2026"),
            .init("Gastroesophageal reflux", "Active · Recorded Nov 14 2025"),
            .init("Acute sinusitis", "Resolved · Recorded Feb 12 2025"),
        ],
        "Allergies": [
            .init("Penicillin", "Severe reaction · Active", detail: .allergy),
            .init("Latex", "Moderate reaction · Active"),
            .init("Shellfish", "Moderate reaction · Active"),
            .init("Sulfamethoxazole", "Mild reaction · Active"),
            .init("Adhesive tape", "Mild reaction · Active"),
            .init("Birch pollen", "Mild reaction · Active"),
            .init("Cat dander", "Severity unknown · Active"),
            .init("Kiwi fruit", "Mild reaction · Inactive"),
        ],
        "Immunizations": [
            .init("Influenza, preservative-free", "Given Oct 12 2026", detail: .immunization),
            .init("COVID-19, 2026–2027 formula", "Given Oct 12 2026"),
            .init("Pneumococcal conjugate, PCV20", "Given Jul 10 2026"),
            .init("Hepatitis B, adult", "Given Apr 8 2026"),
            .init("Hepatitis B, adult", "Given Jan 8 2026"),
            .init("Hepatitis B, adult", "Given Dec 8 2025"),
            .init("Tdap", "Given Nov 14 2025"),
            .init("Influenza, preservative-free", "Given Oct 14 2025"),
        ],
        "Procedures": [
            .init("Venipuncture", "Performed Oct 12 2026", detail: .procedure),
            .init("Diabetic foot examination", "Performed Oct 12 2026"),
            .init("Right knee joint aspiration", "Performed Sep 18 2026"),
            .init("Electrocardiogram", "Performed Jul 10 2026"),
            .init("Retinal photography", "Performed Apr 8 2026"),
            .init("Upper gastrointestinal endoscopy", "Performed Nov 14 2025"),
            .init("Skin lesion biopsy", "Performed Aug 20 2025"),
            .init("Dental extraction", "Performed Jun 3 2025"),
        ],
        "Care Plans": [
            .init("Diabetes self-management", "Active · Oct 12 2026–Jan 12 2027", detail: .carePlan),
            .init("Heart-healthy nutrition", "Active · Oct 12 2026–Apr 12 2027"),
            .init("Knee rehabilitation", "Active · Sep 18–Nov 18 2026"),
            .init("Seasonal allergy management", "Active · Jul 10 2026–Jul 10 2027"),
            .init("Vitamin D replenishment", "Completed · Apr 8–Jul 10 2026"),
            .init("Migraine prevention", "Active · Feb 2 2026–Feb 2 2027"),
            .init("Reflux symptom management", "Active · Nov 14 2025–Nov 14 2026"),
            .init("Post-biopsy wound care", "Completed · Aug 20–Sep 3 2025"),
        ],
        "Medications": [
            .init("Metformin ER 500 mg", "Active · Prescribed Oct 12 2026", detail: .medication),
            .init("Atorvastatin 10 mg", "Active · Prescribed Oct 12 2026"),
            .init("Diclofenac gel 1%", "Active · Prescribed Sep 18 2026"),
            .init("Cetirizine 10 mg", "Active · Prescribed Jul 10 2026"),
            .init("Cholecalciferol 2,000 IU", "Active · Prescribed Apr 8 2026"),
            .init("Sumatriptan 50 mg", "Active · Prescribed Feb 2 2026"),
            .init("Omeprazole 20 mg", "Active · Prescribed Nov 14 2025"),
            .init("Doxycycline 100 mg", "Completed · Prescribed Feb 12 2025"),
        ],
        "Diagnostic Reports": [
            .init("Diabetes monitoring panel", "Oct 12 2026 · Final", detail: .diagnosticReport),
            .init("Lipid assessment", "Oct 12 2026 · Final"),
            .init("Synovial fluid analysis", "Sep 18 2026 · Final"),
            .init("12-lead ECG interpretation", "Jul 10 2026 · Final"),
            .init("Thyroid function report", "Jul 10 2026 · Final"),
            .init("Diabetic retinal screening", "Apr 8 2026 · Final"),
            .init("Upper endoscopy report", "Nov 14 2025 · Final"),
            .init("Skin pathology report", "Aug 22 2025 · Final"),
        ],
        "Imaging": [
            .init("MRI, Right knee", "Sep 22 2026", detail: .imaging),
            .init("X-ray, Right knee", "Sep 18 2026"),
            .init("Ultrasound, Abdomen", "May 14 2026"),
            .init("Retinal photography, Both eyes", "Apr 8 2026"),
            .init("MRI, Brain", "Feb 5 2026"),
            .init("X-ray, Chest", "Dec 2 2025"),
            .init("Ultrasound, Thyroid", "Aug 4 2025"),
            .init("X-ray, Left ankle", "Mar 17 2025"),
        ],
        "Documents and Notes": [
            .init("Visit summary", "Oct 12 2026 · Dr. Maya Chen", detail: .document),
            .init("Nutrition consultation note", "Oct 5 2026 · Elena Ruiz RD"),
            .init("Orthopedic consultation note", "Sep 18 2026 · Dr. Samir Patel"),
            .init("Annual wellness visit summary", "Jul 10 2026 · Dr. Maya Chen"),
            .init("Diabetes follow-up note", "Apr 8 2026 · Dr. Maya Chen"),
            .init("Neurology consultation note", "Feb 2 2026 · Dr. Amara Shah"),
            .init("Endoscopy procedure note", "Nov 14 2025 · Dr. Leo Rivera"),
            .init("Dermatology visit note", "Aug 20 2025 · Dr. Owen Park"),
        ],
        "Forms and Screeners": [
            .init("PHQ-2 depression screening", "Completed Oct 12 2026 · Final", detail: .form),
            .init("Diabetes self-care check-in", "Completed Oct 12 2026 · Final"),
            .init("Nutrition intake questionnaire", "Completed Oct 5 2026 · Final"),
            .init("Knee function questionnaire", "Completed Sep 18 2026 · Final"),
            .init("GAD-2 anxiety screening", "Completed Jul 10 2026 · Final"),
            .init("Social needs screening", "Completed Jul 10 2026 · Final"),
            .init("Alcohol use screening", "Completed Apr 8 2026 · Final"),
            .init("New patient health history", "Completed Nov 14 2025 · Final"),
        ],
        // Sorted most recent first: Colonoscopy (Nov 14 2025) precedes Influenza (Oct 14 2025).
        "Pending Orders": [
            .init("Hemoglobin A1c, repeat", "Ordered · Oct 12 2026", detail: .pendingOrder),
            .init("Lipid panel, follow-up", "Ordered · Oct 12 2026"),
            .init("Right knee MRI, follow-up", "Scheduled · Sep 18 2026"),
            .init("Referral to orthopedics", "Active · Sep 18 2026"),
            .init("Retinal screening, annual", "Scheduled · Apr 8 2026"),
            .init("Colonoscopy screening", "Scheduled · Nov 14 2025"),
            .init("Influenza vaccine, next season", "Pending · Oct 14 2025"),
            .init("Referral to dermatology, follow-up", "Completed · Aug 20 2025"),
        ],
        "Visits": [
            .init("Primary care follow-up", "Oct 12 2026 · Dr. Maya Chen", detail: .visit),
            .init("Nutrition consultation", "Oct 5 2026 · Elena Ruiz RD"),
            .init("Orthopedic consultation", "Sep 18 2026 · Dr. Samir Patel"),
            .init("Annual wellness visit", "Jul 10 2026 · Dr. Maya Chen"),
            .init("Diabetes follow-up", "Apr 8 2026 · Dr. Maya Chen"),
            .init("Neurology consultation", "Feb 2 2026 · Dr. Amara Shah"),
            .init("Outpatient endoscopy", "Nov 14 2025 · Dr. Leo Rivera"),
            .init("Dermatology visit", "Aug 20 2025 · Dr. Owen Park"),
        ],
        "Coverage and Billing": [
            .init("Harbor Primary Care", "Service Oct 12 2026 · Paid", kind: .claim),
            .init("Harbor Nutrition", "Service Oct 5 2026 · Paid", kind: .claim),
            .init("Summit Orthopedics", "Service Sep 18 2026 · Paid", kind: .claim),
            .init("Harbor Primary Care", "Service Jul 10 2026 · Paid", kind: .claim),
            .init("Harbor Primary Care", "Service Apr 8 2026 · Paid", kind: .claim),
            .init("Evergreen Health", "PPO · Jan 1–Dec 31 2026", kind: .coverage),
            .init("Harbor Endoscopy", "Service Nov 14 2025 · Paid", kind: .claim),
            .init("Evergreen Health", "PPO · Jan 1–Dec 31 2025", kind: .coverage),
        ],
    ]
}
