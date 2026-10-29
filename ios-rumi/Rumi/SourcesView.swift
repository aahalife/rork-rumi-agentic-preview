//
//  SourcesView.swift
//  Rumi
//

import HealthKit
import Observation
import SwiftUI

// MARK: - Health systems

struct HealthSystem: Identifiable, Hashable {
    enum Status: Hashable {
        case healthy
        case needsReconnecting
    }

    let id: String
    let name: String
    let platform: String
    let logoAsset: String
    let recordsImported: Int
    var lastUpdated: Date
    var status: Status = .healthy
}

enum HealthSystems {
    static let montefiore = HealthSystem(
        id: "montefiore",
        name: "Montefiore",
        platform: "Epic",
        logoAsset: "MontefioreLogo",
        recordsImported: 342,
        lastUpdated: date(2026, 10, 26, 7, 15)
    )

    static let nyuLangone = HealthSystem(
        id: "nyu-langone",
        name: "NYU Langone",
        platform: "Epic",
        logoAsset: "NYULangoneLogo",
        recordsImported: 128,
        lastUpdated: date(2026, 10, 24, 9, 41),
        status: .needsReconnecting
    )

    /// Systems the placeholder connect flow adds, in order.
    /// Montefiore is healthy; NYU Langone ships flagged as needing reconnection.
    static let seeded: [HealthSystem] = [montefiore, nyuLangone]

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min)) ?? .now
    }
}

// MARK: - Session state (prototype)

/// In-memory source state. Nothing is written to disk, so every fresh
/// launch starts from the defaults: no health systems, Apple Health off.
@Observable
final class SourcesStore {
    static let shared = SourcesStore()

    private(set) var systems: [HealthSystem] = []
    var appleHealthConnected = false
    /// Set right after a failed connect or reconnect attempt; shown at the top of
    /// the Sources content. Not a stored status: cleared when the user leaves
    /// Sources or resolves it.
    private(set) var failureMessage: String?

    var hasHealthRecords: Bool { !systems.isEmpty }

    func system(_ id: String) -> HealthSystem? {
        systems.first { $0.id == id }
    }

    /// Prototype: the first connection brings in the seeded systems; later ones add the next.
    /// Returns true when this was the first connection.
    @discardableResult
    func connectHealthSystem() -> Bool {
        if systems.isEmpty {
            systems = HealthSystems.seeded
            return true
        }
        if let next = HealthSystems.seeded.first(where: { seeded in !systems.contains { $0.id == seeded.id } }) {
            systems.append(next)
        }
        return false
    }

    func reconnectSucceeded(_ id: String, at date: Date) {
        guard let index = systems.firstIndex(where: { $0.id == id }) else { return }
        systems[index].status = .healthy
        systems[index].lastUpdated = date
        failureMessage = nil
    }

    func connectFailed() {
        failureMessage = "Unable to connect your health records, please try again."
    }

    func clearFailure() {
        failureMessage = nil
    }

    func remove(_ id: String) {
        systems.removeAll { $0.id == id }
        failureMessage = nil
    }
}

// MARK: - Apple Health (HealthKit)

enum AppleHealth {
    static let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Read-only access; Rumi never writes to Apple Health.
    static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.stepCount),
        HKQuantityType(.heartRate),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.bodyMass),
        HKQuantityType(.height),
        HKQuantityType(.bloodPressureSystolic),
        HKQuantityType(.bloodPressureDiastolic),
        HKCategoryType(.sleepAnalysis),
    ]

    /// Presents the system HealthKit permission sheet.
    /// Note: for privacy, iOS never reveals whether the user allowed *read*
    /// access, so a completed prompt is the only signal available.
    static func requestAccess() async throws {
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }
}

// MARK: - Sources tab

struct SourcesView: View {
    let onClose: () -> Void
    let onToast: (String) -> Void
    /// Called after the connect sheet has fully dismissed with a first connection.
    let onRecordsConnected: () -> Void

    private let store = SourcesStore.shared

    @State private var showingConnectSheet = false
    @State private var showingStopReadingAlert = false
    @State private var showingUnavailableAlert = false
    @State private var isRequestingHealthAccess = false
    @State private var firstConnectionJustMade = false
    @State private var healthErrorMessage: String?

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            // Universal failure slot: top of content, above every Sources state.
            if let message = store.failureMessage {
                InlineAlert(style: .error, message: message)
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }

            healthRecordsSection
            otherSourcesSection
                .padding(.top, 28)
        }
        .onDisappear {
            // Leaving Sources (switching tab or closing) clears the error.
            // Pushing a detail also disappears this view, so a failure set there
            // is still visible on return.
            store.clearFailure()
        }
        .sheet(isPresented: $showingConnectSheet, onDismiss: {
            // Switch tabs only once the sheet is gone, so the user returns to Records.
            if firstConnectionJustMade {
                firstConnectionJustMade = false
                onRecordsConnected()
            }
        }) {
            FastenConnectSheet(
                onSuccess: {
                    store.clearFailure()
                    firstConnectionJustMade = store.connectHealthSystem()
                },
                onFailure: { withAnimation { store.connectFailed() } }
            )
        }
        .alert(
            "Couldn't connect Apple Health",
            isPresented: Binding(
                get: { healthErrorMessage != nil },
                set: { if !$0 { healthErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(healthErrorMessage ?? "")
        }
        .alert("Stop reading Apple Health?", isPresented: $showingStopReadingAlert) {
            Button("Stop reading", role: .destructive) {
                store.appleHealthConnected = false
            }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Rumi can stop reading your Apple Health data from its side. To fully revoke access, go to Settings › Apps › Rumi › Health.")
        }
        .alert("Apple Health isn't available", isPresented: $showingUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device doesn't support Apple Health.")
        }
    }

    // MARK: Section 1 — Health Records

    @ViewBuilder
    private var healthRecordsSection: some View {
        VStack(spacing: 0) {
            GlassSectionHeader(title: "Health Records")

            if store.systems.isEmpty {
                VStack(spacing: 16) {
                    FAIconView(icon: .sparkles, size: 20)
                        .foregroundStyle(Color.brandPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.fillTertiary, in: Circle())

                    Text("Connect your health records so Rumi can give you more personalized insights and support.")
                        .font(.rumiBody)
                        .foregroundStyle(Color.labelSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        showingConnectSheet = true
                    } label: {
                        Text("Connect health records")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.brandPrimary)
                    .controlSize(.large)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .glassCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.systems.enumerated()), id: \.element.id) { index, system in
                        if index > 0 { GlassDivider(leadingInset: 60, thickness: 1) }

                        NavigationLink {
                            HealthSystemDetailView(systemID: system.id, onClose: onClose)
                        } label: {
                            HealthSystemRow(system: system)
                        }
                        .buttonStyle(GlassRowButtonStyle())

                    }
                }
                .glassCard()

                Button {
                    showingConnectSheet = true
                } label: {
                    Text("Add health system")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .tint(.brandPrimary)
                .controlSize(.large)
                .padding(.top, 16)
            }
        }
    }

    // MARK: Section 2 — Other Sources

    private var otherSourcesSection: some View {
        VStack(spacing: 0) {
            GlassSectionHeader(title: "Other Sources")

            HStack(spacing: 14) {
                Image("AppleHealthLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Apple Health")
                        .font(.rumiBody)
                        .foregroundStyle(Color.labelPrimary)
                    Text(store.appleHealthConnected ? "Data syncing from Health." : "Sync data from Health.")
                        .font(.rumiSubheadline)
                        .foregroundStyle(Color.labelSecondary)
                }

                Spacer(minLength: 8)

                Toggle("Apple Health", isOn: appleHealthToggle)
                    .labelsHidden()
                    .tint(.brandPrimary)
                    .disabled(isRequestingHealthAccess)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassCard()
        }
    }

    // MARK: Actions

    /// On connects through HealthKit; off explains first, never silently disconnects.
    private var appleHealthToggle: Binding<Bool> {
        Binding(
            get: { store.appleHealthConnected },
            set: { isOn in
                if isOn {
                    connectAppleHealth()
                } else {
                    showingStopReadingAlert = true
                }
            }
        )
    }

    private func connectAppleHealth() {
        guard AppleHealth.isAvailable else {
            showingUnavailableAlert = true
            return
        }
        isRequestingHealthAccess = true
        Task {
            defer { isRequestingHealthAccess = false }
            do {
                try await AppleHealth.requestAccess()
                store.appleHealthConnected = true
                onToast("Apple Health connected")
            } catch {
                // Toggle stays off; surface the reason instead of failing silently.
                print("[HealthKit] requestAuthorization failed: \(error)")
                healthErrorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Health system row

/// Design-system list row: 17pt vertical padding, 16pt leading inset,
/// 32pt icon, 12pt icon-to-text gap, 24pt chevron box, 16pt trailing inset.
struct HealthSystemRow: View {
    let system: HealthSystem

    var body: some View {
        HStack(spacing: 12) {
            HealthSystemLogo(system: system, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(system.name)
                    .font(.rumiBody)
                    .foregroundStyle(Color.labelPrimary)
                Text(statusLine)
                    .font(.rumiSubheadline)
                    .foregroundStyle(system.status == .needsReconnecting ? Color.orange : Color.labelSecondary)
            }

            Spacer(minLength: 8)

            RowChevron()
                .frame(width: 24, height: 24)
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.vertical, 17)
        .frame(minHeight: 57)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var statusLine: String {
        switch system.status {
        case .healthy:
            return "Last update: \(system.lastUpdated.formatted(.dateTime.month(.twoDigits).day(.twoDigits).year(.twoDigits)))"
        case .needsReconnecting:
            let date = system.lastUpdated.formatted(.dateTime.month(.abbreviated).day())
            let time = system.lastUpdated.formatted(date: .omitted, time: .shortened)
            return "Needs reconnecting · Last synced \(date), \(time)"
        }
    }
}

/// Square health-system logo from the supplied artwork.
struct HealthSystemLogo: View {
    let system: HealthSystem
    let size: CGFloat

    var body: some View {
        Image(system.logoAsset)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Inline alert

/// Inline alert per Figma: 8pt corners, 16pt padding, 32pt icon slot with a 24pt glyph.
struct InlineAlert: View {
    enum Style {
        case warning
        case error

        var fill: Color { self == .warning ? .alertWarningFill : .alertErrorFill }
        var label: Color { self == .warning ? .labelPrimary : .alertErrorLabel }
        var icon: FAIcon { self == .warning ? .triangleExclamation : .circleExclamation }
    }

    let style: Style
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FAIconView(icon: style.icon, size: 24)
                .foregroundStyle(style.label)
                .frame(width: 32, height: 32)

            Text(message)
                .font(.rumiSubheadline)
                .foregroundStyle(style.label)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Health system connection detail

struct HealthSystemDetailView: View {
    let systemID: String
    let onClose: () -> Void

    private enum ReconnectResult { case success, failure }

    private let store = SourcesStore.shared

    @State private var showingRemoveConfirmation = false
    @State private var showingReconnectSheet = false
    @State private var pendingResult: ReconnectResult?
    @State private var isRefreshing = false
    @State private var toast: String?
    /// Only true right after a failed attempt; a fresh visit shows the warning instead.
    @State private var showingReconnectError = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let system = store.system(systemID) {
            content(system)
        } else {
            ScreenBackground()
        }
    }

    private func content(_ system: HealthSystem) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    HealthSystemLogo(system: system, size: 64)
                    VStack(spacing: 4) {
                        Text(system.name)
                            .font(.rumiTitle2)
                            .foregroundStyle(Color.labelPrimary)
                        Text(system.platform)
                            .font(.rumiSubheadline)
                            .foregroundStyle(Color.labelSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                // Shown only while the connection needs reconnecting.
                if system.status == .needsReconnecting {
                    Group {
                        if showingReconnectError {
                            InlineAlert(
                                style: .error,
                                message: "Unable to reconnect to \(system.name), please try again."
                            )
                        } else {
                            InlineAlert(
                                style: .warning,
                                message: "This connection has expired. Reconnect to continue to access the latest data."
                            )
                        }
                    }
                    .padding(.top, 24)
                    .transition(.opacity)
                }

                // Metadata
                VStack(spacing: 0) {
                    metadataRow("Records Imported", value: "\(system.recordsImported)")
                    GlassDivider(leadingInset: 16)
                    metadataRow(
                        "Last Updated",
                        value: system.lastUpdated.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
                    )
                }
                .redacted(reason: isRefreshing ? .placeholder : [])
                .overlay {
                    if isRefreshing { ProgressView() }
                }
                .glassCard()
                .padding(.top, 24)
            }
            .padding(.horizontal, .screenMargin)
            .padding(.bottom, 32)
        }
        .background { ScreenBackground() }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if system.status == .needsReconnecting {
                    Button {
                        showingReconnectSheet = true
                    } label: {
                        Text("Reconnect")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.brandPrimary)
                    .controlSize(.large)
                }

                Button(role: .destructive) {
                    showingRemoveConfirmation = true
                } label: {
                    Text("Remove connection")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
            .disabled(isRefreshing)
            .padding(.horizontal, .screenMargin)
            .padding(.bottom, 8)
        }
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .close) { onClose() }
            }
        }
        // Same native alert used for the app's other destructive confirmations.
        .alert("Remove \(system.name)?", isPresented: $showingRemoveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove connection", role: .destructive) {
                dismiss()
                store.remove(system.id)
            }
        } message: {
            Text("Rumi will stop syncing records from \(system.name).")
        }
        .sheet(isPresented: $showingReconnectSheet, onDismiss: { runPendingRefresh(system) }) {
            FastenConnectSheet(
                onSuccess: { pendingResult = .success },
                onFailure: { pendingResult = .failure }
            )
        }
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.rumiBody)
                .foregroundStyle(Color.labelPrimary)
            Spacer(minLength: 8)
            Text(value)
                .font(.rumiBody)
                .foregroundStyle(Color.labelSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    /// Runs after the sheet is fully gone: brief loading, then the outcome.
    private func runPendingRefresh(_ system: HealthSystem) {
        guard let result = pendingResult else { return }
        pendingResult = nil
        withAnimation { showingReconnectError = false }
        isRefreshing = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            isRefreshing = false
            withAnimation {
                switch result {
                case .success:
                    store.reconnectSucceeded(system.id, at: Date())
                    toast = "\(system.name) reconnected"
                case .failure:
                    // Shown only here, where the reconnect was started — never on Sources.
                    showingReconnectError = true
                }
            }
        }
    }
}

// MARK: - Fasten placeholder sheet

/// Full-page stand-in for the Fasten provider flow, used for every connect and reconnect.
private struct FastenConnectSheet: View {
    let onSuccess: () -> Void
    let onFailure: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Fasten Integration")
                    .font(.rumiBody)
                    .foregroundStyle(Color.labelPrimary)
                    .padding(.bottom, 12)

                Button {
                    onSuccess()
                    dismiss()
                } label: {
                    Text("Simulate success")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.brandPrimary)
                .controlSize(.large)

                Button(role: .destructive) {
                    onFailure()
                    dismiss()
                } label: {
                    Text("Simulate failure")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
            .padding(.horizontal, .screenMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { ScreenBackground() }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Records empty state

struct RecordsEmptyState: View {
    var body: some View {
        ContentUnavailableView {
            Label("No insights yet", systemImage: "sparkles")
        } description: {
            Text("Rumi will generate insights here once you connect your health records or talk with Rumi more about your health.")
        }
    }
}

// MARK: - Toast

struct SuccessToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.brandPrimary)
            Text(message)
                .font(.rumiSubheadline)
                .foregroundStyle(Color.labelPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: Capsule())
        .sensoryFeedback(.success, trigger: message)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}
