//
//  RecordDetailView.swift
//  Rumi
//
//  Tier 3 record detail: native large title + subtitle, then the existing
//  section header + glass card + row components.
//

import SwiftUI

struct RecordDetailView: View {
    let id: RecordDetailID
    let onClose: () -> Void

    var body: some View {
        let detail = RecordDetails.detail(id)

        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(detail.sections.enumerated()), id: \.element.id) { index, section in
                    sectionView(section)
                        .padding(.top, index == 0 ? 16 : 28)
                }

                if detail.showsPatientFooter {
                    VStack(spacing: 2) {
                        Text(RecordDetails.patientLine)
                        Text(RecordDetails.sourceLine)
                    }
                    .font(.rumiFootnote)
                    .foregroundStyle(Color.labelTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                }
            }
            .padding(.horizontal, .screenMargin)
            .padding(.bottom, 32)
        }
        .background { ScreenBackground() }
        .navigationTitle(detail.title)
        .navigationSubtitle(detail.subtitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .close) { onClose() }
            }
        }
    }

    private func sectionView(_ section: DetailSection) -> some View {
        VStack(spacing: 0) {
            GlassSectionHeader(title: section.title)

            VStack(spacing: 0) {
                if let intro = section.intro {
                    Text(intro)
                        .font(.rumiSubheadline)
                        .foregroundStyle(Color.labelSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    GlassDivider(leadingInset: 16)
                }

                ForEach(Array(section.fields.enumerated()), id: \.element.id) { index, field in
                    if index > 0 { GlassDivider(leadingInset: 16) }
                    fieldRow(field)
                }
            }
            .glassCard()
        }
    }

    @ViewBuilder
    private func fieldRow(_ field: DetailField) -> some View {
        switch field.link {
        case .record(let target):
            NavigationLink {
                RecordDetailView(id: target, onClose: onClose)
            } label: {
                DetailFieldRow(field: field, showsChevron: true)
            }
            .buttonStyle(GlassRowButtonStyle())
        case .unavailable:
            // TODO: Linked record has no detail screen yet.
            Button {} label: {
                DetailFieldRow(field: field, showsChevron: true)
            }
            .buttonStyle(GlassRowButtonStyle())
        case nil:
            DetailFieldRow(field: field, showsChevron: false)
        }
    }
}

private struct DetailFieldRow: View {
    let field: DetailField
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(field.label)
                    .font(.rumiSubheadline)
                    .foregroundStyle(Color.labelSecondary)
                Text(field.value)
                    .font(.rumiBody)
                    .foregroundStyle(Color.labelPrimary)
                if let note = field.note {
                    Text(note)
                        .font(.rumiSubheadline)
                        .foregroundStyle(Color.labelSecondary)
                }
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if showsChevron { RowChevron() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        RecordDetailView(id: .claim, onClose: {})
    }
}
