//
//  HealthView.swift
//  Rumi
//

import SwiftUI

// MARK: - Font Awesome Pro glyphs

/// Icons from the bundled Font Awesome 7 Pro Light font.
/// FA5-era names map to their glyphs (allergies → hand-dots,
/// procedures → bed-pulse, diagnoses → person-dots-from-line).
enum FAIcon: String {
    case flask = "\u{f0c3}"
    case heartPulse = "\u{f21e}"
    case notesMedical = "\u{f481}"
    case allergies = "\u{f461}"
    case syringe = "\u{f48e}"
    case procedures = "\u{f487}"
    case clipboardList = "\u{f46d}"
    case pills = "\u{f484}"
    case diagnoses = "\u{f470}"
    case xRay = "\u{f497}"
    case fileLines = "\u{f15c}"
    case clipboardCheck = "\u{f46c}"
    case hourglassHalf = "\u{f252}"
    case calendarCheck = "\u{f274}"
    case creditCard = "\u{f09d}"
    case shieldHalved = "\u{f3ed}"
    case heart = "\u{f004}"
    case user = "\u{f007}"
    case sparkles = "\u{f890}"
    case triangleExclamation = "\u{f071}"
    case circleExclamation = "\u{f06a}"
    case thumbsUp = "\u{f164}"
    case thumbsDown = "\u{f165}"
    case copy = "\u{f0c5}"
    case arrowUpFromSquare = "\u{e09c}"
    case ellipsis = "\u{f141}"
}

struct FAIconView: View {
    let icon: FAIcon
    var size: CGFloat = 17

    var body: some View {
        Text(icon.rawValue)
            .font(.custom("FontAwesome7Pro-Light", size: size))
            .accessibilityHidden(true)
    }
}

// MARK: - Data

struct HealthCategory: Identifiable, Hashable {
    let title: String
    let icon: FAIcon

    var count: Int { HealthRecordsData.items(for: title).count }

    var id: String { title }
}

private let healthRecordRows: [HealthCategory] = [
    .init(title: "Labs", icon: .flask),
    .init(title: "Vitals", icon: .heartPulse),
    .init(title: "Conditions", icon: .notesMedical),
    .init(title: "Allergies", icon: .allergies),
    .init(title: "Immunizations", icon: .syringe),
    .init(title: "Procedures", icon: .procedures),
    .init(title: "Care Plans", icon: .clipboardList),
    .init(title: "Medications", icon: .pills),
]

private let reportsAndCareRows: [HealthCategory] = [
    .init(title: "Diagnostic Reports", icon: .diagnoses),
    .init(title: "Imaging", icon: .xRay),
    .init(title: "Documents and Notes", icon: .fileLines),
    .init(title: "Forms and Screeners", icon: .clipboardCheck),
    .init(title: "Pending Orders", icon: .hourglassHalf),
    .init(title: "Visits", icon: .calendarCheck),
    .init(title: "Coverage and Billing", icon: .creditCard),
]

// MARK: - Health screen

enum HealthSegment: String, CaseIterable, Identifiable {
    case records = "Records"
    case sources = "Sources"
    var id: String { rawValue }
}

struct HealthView: View {
    /// Exits the whole menu flow (dismisses the sheet).
    let onClose: () -> Void

    @State private var segment: HealthSegment = .records
    @State private var toast: String?

    private let sources = SourcesStore.shared

    private var hasConnectedSource: Bool { sources.hasHealthRecords || sources.appleHealthConnected }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Always visible, even before any source is connected.
                PillSegmentedControl(selection: $segment)
                    .padding(.top, 8)

                switch segment {
                case .records:
                    NavigationLink { HealthTrendsView() } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "chart.xyaxis.line").foregroundStyle(Color.brandPrimary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Health trends").font(.rumiHeadline)
                                Text("Your dated measurements & sources").font(.rumiFootnote).foregroundStyle(Color.labelSecondary)
                            }
                            Spacer()
                            RowChevron()
                        }.padding(16).glassCard()
                    }.buttonStyle(.plain).padding(.top, 20)
                    if hasConnectedSource {
                        categorySection("Health Records", rows: healthRecordRows)
                            .padding(.top, 24)
                        categorySection("Reports and Care", rows: reportsAndCareRows)
                            .padding(.top, 28)
                    } else {
                        RecordsEmptyState()
                            .padding(.top, 72)
                    }
                case .sources:
                    SourcesView(
                        onClose: onClose,
                        onToast: { message in
                            withAnimation { toast = message }
                        },
                        onRecordsConnected: {
                            withAnimation {
                                segment = .records
                                toast = "Health Records connected"
                            }
                        }
                    )
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, .screenMargin)
            .padding(.bottom, 32)
        }
        .background { ScreenBackground() }
        .overlay(alignment: .bottom) {
            if let toast {
                SuccessToast(message: toast)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: toast) {
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation { self.toast = nil }
                    }
            }
        }
        .navigationTitle("Health")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .close) { onClose() }
            }
        }
    }

    private func categorySection(_ title: String, rows: [HealthCategory]) -> some View {
        VStack(spacing: 0) {
            GlassSectionHeader(title: title)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { GlassDivider() }
                    // Each row pushes its own dedicated page, titled to match the row.
                    NavigationLink {
                        HealthCategoryListView(category: row, onClose: onClose)
                    } label: {
                        HealthCategoryRow(category: row)
                    }
                    .buttonStyle(GlassRowButtonStyle())
                }
            }
            .glassCard()
        }
    }
}

private struct HealthCategoryRow: View {
    let category: HealthCategory

    var body: some View {
        HStack(spacing: 14) {
            FAIconView(icon: category.icon)
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 24)

            Text(category.title)
                .font(.rumiBody)
                .foregroundStyle(Color.labelPrimary)

            Spacer(minLength: 8)

            Text("\(category.count)")
                .font(.rumiFootnote)
                .foregroundStyle(Color.labelSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.fillSecondary, in: Capsule())
                .accessibilityLabel("\(category.count) items")

            RowChevron()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

// MARK: - Pill segmented control

private struct PillSegmentedControl: View {
    @Binding var selection: HealthSegment
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(HealthSegment.allCases) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selection = option
                    }
                } label: {
                    Text(option.rawValue)
                        .font(.rumiHeadline)
                        .foregroundStyle(isSelected ? Color.labelPrimaryContrast : Color.labelPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Color.brandPrimary)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.fillSecondary, in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - Category list (Tier 2)

struct HealthCategoryListView: View {
    let category: HealthCategory
    let onClose: () -> Void

    var body: some View {
        let items = HealthRecordsData.items(for: category.title)

        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { GlassDivider(leadingInset: 16) }
                    if let detail = item.detail {
                        NavigationLink {
                            RecordDetailView(id: detail, onClose: onClose)
                        } label: {
                            HealthItemRow(item: item)
                        }
                        .buttonStyle(GlassRowButtonStyle())
                    } else {
                        // TODO: Tier 3 detail screen not built for this row yet.
                        HealthItemRow(item: item)
                    }
                }
            }
            .glassCard()
            .padding(.horizontal, .screenMargin)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background { ScreenBackground() }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .close) { onClose() }
            }
        }
    }
}

private struct HealthItemRow: View {
    let item: HealthItem

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.primary)
                        .font(.rumiBody)
                        .foregroundStyle(Color.labelPrimary)
                    kindTag
                }
                Text(item.secondary)
                    .font(.rumiSubheadline)
                    .foregroundStyle(Color.labelSecondary)
            }

            Spacer(minLength: 8)

            RowChevron()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var kindTag: some View {
        switch item.kind {
        case .standard:
            EmptyView()
        case .claim:
            tag("Claim", text: .labelSecondary, fill: .fillSecondary)
        case .coverage:
            tag("Coverage", text: .brandTertiaryShade, fill: .brandTertiaryTint)
        }
    }

    private func tag(_ label: String, text: Color, fill: Color) -> some View {
        Text(label)
            .font(.rumiCaption1)
            .foregroundStyle(text)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(fill, in: Capsule())
    }
}

#Preview {
    NavigationStack {
        HealthView(onClose: {})
    }
}
