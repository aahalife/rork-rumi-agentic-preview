import SwiftUI

/// Inert, recognizable third-party layouts; real passwords never enter these mockups.
struct SampleSitePreviewView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pointer
    let demo: BrowserDemoModel
    let scenario: BrowserDemoModel.Scenario
    private var health: Bool { scenario == .labs || scenario == .visit }
    private var social: Bool { scenario == .recipe || scenario == .activity }
    private var brand: String { health ? "MyChart" : social ? "Instagram" : "Uber" }
    private var siteColor: Color { health ? Color(red: 0.086, green: 0.388, blue: 0.667) : social ? Color(red: 0, green: 0.584, blue: 0.965) : .black }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                Image(systemName: "lock.fill")
                Text("\(brand) · \(demo.phase == .login ? "Sign in" : scenario == .labs ? "Test results" : scenario == .visit ? "Messages" : social ? "Saved" : "Review trip")").lineLimit(1)
                Spacer(minLength: 0)
                Text("Mockup").foregroundStyle(.gray)
            }
            .font(.system(size: 11)).padding(12).background(Color(white: 0.96))
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal").font(.system(size: 15))
                Text(brand).font(social ? .system(size: 27, weight: .bold, design: .serif).italic() : .system(size: 26, weight: health ? .bold : .medium))
                Spacer()
                if demo.phase != .login { Text(demo.patientName).font(.system(size: 12)) }
            }
            .padding(16).foregroundStyle(health ? .white : .black).background(health ? siteColor : .white)
            VStack(alignment: .leading, spacing: 14) {
                if demo.phase == .login {
                    login
                } else {
                    page
                }
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.black).background(.white)
        .animation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.8), value: demo.step)
    }

    private var login: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(health ? "Sign in to MyChart" : social ? "Welcome back" : "What’s your phone number or email?")
                .font(.system(size: 21, weight: .semibold))
            field(health ? "MyChart username" : social ? "Phone number, username, or email" : "Email", value: "\(demo.patientName.lowercased()).sample")
            if health || social { field("Password", value: "••••••••••••") }
            Button { demo.continueDemoLogin() } label: {
                Text("Sign in as \(demo.patientName)").font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 48).foregroundStyle(.white).background(siteColor, in: .rect(cornerRadius: 5))
            }.buttonStyle(.plain)
            HStack { Text(health ? "Forgot username?" : "Sample account only"); Spacer(); if health || social { Text("Forgot password?") } }
                .font(.system(size: 11)).foregroundStyle(.gray)
            Text("\(brand)-style page · Fixed sample login. No real credentials or live connection.")
                .font(.system(size: 11)).foregroundStyle(.gray)
        }
    }

    private func field(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 12)).foregroundStyle(.gray)
            Text(value).font(.system(size: 14)).padding(12).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(Color(white: 0.97), in: .rect(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.gray.opacity(0.25)))
        }.accessibilityElement(children: .combine)
    }

    @ViewBuilder private var page: some View {
        if health {
            HStack(spacing: 18) { Text("Home"); Text("Visits"); Text("Messages") }
                .font(.system(size: 12)).foregroundStyle(siteColor)
            Text(scenario == .labs ? "Test results" : demo.step == 0 ? "Upcoming visit" : "Draft for your care team")
                .font(.system(size: 22, weight: .bold))
            if scenario == .labs {
                ForEach(Array(app.labSeries.prefix(3).enumerated()), id: \.element.id) { index, series in
                    target(index) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(series.name).font(.system(size: 14, weight: .semibold))
                                Text(series.provenance).font(.system(size: 11)).foregroundStyle(.gray)
                            }
                            Spacer()
                            Text("\(series.latest?.value.formatted() ?? "—") \(series.unit)").font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
            } else {
                target(0) { VStack(alignment: .leading, spacing: 4) {
                    Text(app.appointments.first?.with ?? app.persona.officeName).font(.system(size: 14, weight: .bold))
                    Text(app.appointments.first?.location ?? "Clinic").font(.system(size: 12)).foregroundStyle(.gray)
                } }
                target(1) { VStack(alignment: .leading, spacing: 6) { Text("Message").font(.system(size: 12)).foregroundStyle(.gray); Text(demo.reviewText).font(.system(size: 14)) } }
                target(2) { VStack(alignment: .leading, spacing: 4) { Text("Review message →").font(.system(size: 14, weight: .semibold)).foregroundStyle(siteColor); Text("Not sent · waiting for your permission").font(.system(size: 11)).foregroundStyle(.gray) } }
            }
        } else if scenario == .activity {
            target(0) {
                Color(white: 0.95).frame(height: 220)
                    .overlay { Image("mobility_stretch_walk").resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false) }
                    .clipShape(.rect(cornerRadius: 12))
            }
            target(1) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("@move.kindly · fictional saved post").font(.system(size: 12)).foregroundStyle(.gray)
                    Text("15 minutes for a less stiff afternoon").font(.system(size: 16, weight: .semibold))
                    Text("5 min comfortable standing mobility, then a 10 min easy walk. No jumping. Follow care-team limits; stop if uncomfortable.").font(.system(size: 14))
                }
            }
            target(2) { Text("A local plan, not completed activity. Prepared artwork, not runtime image generation.").font(.system(size: 12)) }
        } else if social {
            target(0) { Label("Saved · Recipes", systemImage: "bookmark").font(.system(size: 14, weight: .semibold)) }
            target(1) { VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "carrot.fill").font(.system(size: 48)).foregroundStyle(.green.opacity(0.6))
                    .frame(maxWidth: .infinity, minHeight: 100).background(Color(white: 0.95), in: .rect(cornerRadius: 8))
                Text("Chickpea & herb bowl").font(.system(size: 15, weight: .semibold))
                Text("From your sample saved collection").font(.system(size: 12)).foregroundStyle(.gray)
            } }
            target(2) { Label("Recipe ready to review", systemImage: "heart").font(.system(size: 14)) }
        } else {
            Text("Where to?").font(.system(size: 24, weight: .semibold))
            target(0) { VStack(alignment: .leading, spacing: 4) { Text("Pickup").font(.system(size: 12)).foregroundStyle(.gray); Text("Home").font(.system(size: 15, weight: .semibold)) } }
            target(1) { VStack(alignment: .leading, spacing: 4) { Text("Destination").font(.system(size: 12)).foregroundStyle(.gray); Text(app.appointments.first?.location ?? "Clinic").font(.system(size: 15, weight: .semibold)); Text("45 minutes before your appointment").font(.system(size: 11)).foregroundStyle(.gray) } }
            target(2) { HStack { Image(systemName: "car.fill").font(.system(size: 26)); VStack(alignment: .leading) { Text("UberX").font(.system(size: 16, weight: .bold)); Text("Sample fare · not a live quote").font(.system(size: 11)).foregroundStyle(.gray) }; Spacer(); Text("$\(demo.fare)").font(.system(size: 18, weight: .semibold)) } }
        }
    }

    private func target<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        let active = demo.phase == .browsing && demo.step == index
        return content().frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .id(index)
            .background(active ? Color(red: 0.92, green: 0.99, blue: 0.96) : .white, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(active ? Theme.brandMint : Color.gray.opacity(0.2), lineWidth: active ? 2 : 1))
            .overlay(alignment: .trailing) {
                if active {
                    Circle().fill(Theme.brandForest).frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .shadow(color: Theme.brandMint, radius: 9)
                        .matchedGeometryEffect(id: "agentPointer", in: pointer).padding(.trailing, 26)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
    }
}
