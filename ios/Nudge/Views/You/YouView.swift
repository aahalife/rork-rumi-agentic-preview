import SwiftUI

enum YouDestination: Hashable {
    case records
    case category(RecordCategory)
    case labDetail(String)
    case medications
    case medDetail(String)
    case care
    case visitPrep
    case conditions
    case guide
    case life
}

/// "You" — the health story. Story · Insights as one segmented pair, with the
/// conditions overview, discussion guide, and records drawer one tap away.
struct YouView: View {
    @Environment(AppModel.self) private var model
    @State private var section: Section = .insights
    @State private var path = NavigationPath()
    @State private var library: Library? = nil

    private enum Library: String, Identifiable {
        case journeys, currents, connections
        var id: String { rawValue }
    }

    enum Section: String, CaseIterable {
        case insights = "Insights"
        case story = "Story"
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LivingGradientView()

                VStack(spacing: 0) {
                    header
                    Button { library = .journeys } label: {
                        HStack(spacing: 12) {
                            BrandGlyph(systemName: "leaf")
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Your journeys").font(NudgeType.serif(20))
                                Text("One small habit. At your own pace.").font(NudgeType.rounded(14))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(Theme.brandForest)
                        .padding(16)
                        .frostedSurface(radius: 28)
                    }
                    .buttonStyle(NudgeButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    quickDoors
                    Text("\(model.persona.firstName)’s sample insights · not imported records")
                        .font(NudgeType.rounded(13)).foregroundStyle(Theme.inkMuted)
                        .padding(.horizontal, 20).padding(.bottom, 8)

                    switch section {
                    case .story:
                        StoryTimelineView()
                            .transition(.opacity)
                    case .insights:
                        InsightsHubView()
                            .transition(.opacity)
                    }
                }
            }
            .navigationDestination(for: YouDestination.self) { destination in
                destinationView(destination)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $library) { destination in
                NavigationStack {
                    ZStack {
                        LivingGradientView()
                        switch destination {
                        case .journeys: JourneysView()
                        case .currents: CurrentsView()
                        case .connections: ConnectionsView()
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { library = nil }
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .nudgeOpenConditions)) { _ in
                if path.isEmpty {
                    path.append(YouDestination.conditions)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .nudgeOpenLife)) { _ in
                if path.isEmpty {
                    path.append(YouDestination.life)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            GlassSurface(radius: 24) {
                HStack(spacing: 4) {
                    ForEach(Section.allCases, id: \.self) { item in
                        let selected = section == item
                        Button {
                            Haptics.tick()
                            withAnimation(NudgeSpring.ui) { section = item }
                        } label: {
                            Text(item.rawValue)
                                .font(NudgeType.rounded(13, selected ? .semibold : .medium))
                                .foregroundStyle(selected ? Theme.ink : Theme.inkMuted)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background {
                                    if selected {
                                        Capsule().fill(Theme.surface.opacity(0.9))
                                    }
                                }
                        }
                        .buttonStyle(NudgeButtonStyle())
                    }
                }
                .padding(4)
            }

            Spacer()
            Menu {
                Button("Journeys & habits", systemImage: "leaf") { library = .journeys }
                Button("Currents · read & listen", systemImage: "water.waves") { library = .currents }
                Button("Meals & activity", systemImage: "fork.knife") { path.append(YouDestination.life) }
                Button("Care team", systemImage: "stethoscope") { path.append(YouDestination.care) }
                Button("Connections", systemImage: "link") { library = .connections }
                Button("Settings & privacy", systemImage: "slider.horizontal.3") { model.showSettings = true }
            } label: {
                Image(systemName: "ellipsis").frame(width: 44, height: 44)
                    .foregroundStyle(Theme.brandForest)
            }
            .accessibilityLabel("Your library and settings")
            .padding(.trailing, 46)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    /// The doors that were buried — conditions & plan, the discussion guide,
    /// care team & visits. Present on the surface, calm as chips.
    private var quickDoors: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                door(glyph: "text.book.closed", label: "Discussion guide", accent: Theme.gold,
                     badge: model.guideItems.filter { !$0.resolved }.count) {
                    path.append(YouDestination.guide)
                }
                door(glyph: "leaf", label: "Journeys", accent: Theme.brandForest) {
                    library = .journeys
                }
                door(glyph: "water.waves", label: "Currents", accent: Theme.sky) {
                    library = .currents
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func door(glyph: String, label: String, accent: Color,
                      badge: Int = 0, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tick()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: glyph)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accent)
                Text(label)
                    .font(NudgeType.rounded(12, .medium))
                    .foregroundStyle(Theme.ink)
                if badge > 0 {
                    Text("\(badge)")
                        .font(NudgeType.number(10, .semibold))
                        .foregroundStyle(Theme.base)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accent, in: .capsule)
                }
            }
            .padding(.horizontal, 13)
            .frame(minHeight: 44)
            .background(.ultraThinMaterial, in: .capsule)
            .overlay(Capsule().strokeBorder(accent.opacity(0.35), lineWidth: 0.9))
        }
        .buttonStyle(NudgeButtonStyle())
    }

    @ViewBuilder
    private func destinationView(_ destination: YouDestination) -> some View {
        ZStack {
            LivingGradientView()
            switch destination {
            case .records:
                RecordsDrawerView()
            case .category(let category):
                RecordCategoryView(category: category)
            case .labDetail(let seriesID):
                if let series = model.series(seriesID) {
                    LabDetailView(series: series)
                }
            case .medications:
                MedicationsView()
            case .medDetail(let medID):
                if let med = model.medications.first(where: { $0.id == medID }) {
                    MedDetailView(medication: med)
                }
            case .care:
                CareTeamView()
            case .visitPrep:
                VisitPrepView()
            case .conditions:
                ConditionOverviewView()
            case .guide:
                DiscussionGuideView()
            case .life:
                LifeCatalogView()
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.visible, for: .navigationBar)
    }
}
