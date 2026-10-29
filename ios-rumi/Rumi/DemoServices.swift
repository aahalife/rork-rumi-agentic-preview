import SwiftUI

// All service mockups are native local views: no WebView, URLSession, OAuth,
// location, payment or deep-link invocation is present in this file.
enum DemoPrimaryProfile {
    static let context = """
    PRIMARY SUPPLIED FICTIONAL DEMO PROFILE. Name and age were not supplied; display as Primary demo member. Do not infer this is the presenter or import Maria/Tom facts. Long-standing type 2 diabetes and hyperlipidemia. Prior labs about nine months before demo baseline: HbA1c 9.0%, LDL-C 130 mg/dL, eGFR 60 mL/min/1.73 m². PCP visit six months after those labs: no medication changes; repeat labs ordered but unavailable before leaving. Several weeks after visit: HbA1c 8.8%, LDL-C 130 mg/dL, eGFR 55 mL/min/1.73 m². Exact dates not supplied; chart dates are illustrative offsets, not actual lab timestamps. Supplied medication list: atorvastatin 40 mg, metformin ER 2000 mg, Mounjaro (tirzepatide) 12.5 mg. Frequency, adherence, allergies, weight, age, personal targets and subsequent clinician instructions are unknown. Do not infer frequency or prescribe changes. No insulin or semaglutide order story belongs to this member.
    Supplied talking points concern persistent A1c/LDL elevations and kidney health. Treat suggestions about SGLT2 inhibitors, Jardiance/Farxiga, lipid adjustments and target values as clinician discussion topics only, not a recommendation that a medicine is suitable, a diagnosis derived from two results or proof of treatment failure/adherence. Ask which A1c/LDL targets fit the person's clinical history and what the clinician recommends about kidney protection and cholesterol. Do not assert highest/maximum doses or create a medication change. No real record import or provider connection occurred.
    """
}

struct DemoPrimarySummary: View {
    var body: some View {
        Text("Primary profile · Supplied scenario").font(.headline)
        Text("Long-standing type 2 diabetes and hyperlipidemia. Name, age, weight and exact dates were not supplied.")
        LabeledContent("HbA1c", value: "9.0% → 8.8%")
        LabeledContent("LDL-C", value: "130 → 130 mg/dL")
        LabeledContent("eGFR", value: "60 → 55 mL/min/1.73 m²")
        Text("Atorvastatin 40 mg\nMetformin ER 2000 mg\nMounjaro 12.5 mg").font(.body)
        Text("Supplied regimen; frequency and current adherence not specified. PCP made no changes at the described visit; repeat labs arrived several weeks later.").font(.callout)
        DisclosureGroup("Questions to prepare for my PCP") {
            Text("Which A1c and LDL-C targets are appropriate for me?\nWhat do the repeat kidney results mean in my history?\nShould we discuss kidney-protective diabetes treatments, including whether an SGLT2 inhibitor is appropriate?\nShould my cholesterol plan be reviewed?").padding(.vertical, 8)
        }
        Text("Questions, not medication recommendations. No new medicine, dosing change or diagnosis is generated here.").font(.footnote)
    }
}

enum DemoMockRecipe: String, CaseIterable, Identifiable {
    case bowl, tray
    var id: String { rawValue }
    var title: String { self == .bowl ? "Lemon chickpea & rice bowl" : "Salmon & broccoli tray dinner" }
    var creator: String { self == .bowl ? "weekday.table.demo" : "onepan.kitchen.demo" }
    var symbol: String { self == .bowl ? "carrot.fill" : "fish.fill" }
    var color: Color { self == .bowl ? .orange : .teal }
    var ingredients: [DemoRecipeIngredient] {
        if self == .bowl {
            return [.init(name: "Chickpeas", amount: 1, unit: "can", pantryKey: "chickpeas"), .init(name: "Brown rice", amount: 150, unit: "g", pantryKey: "brown_rice"), .init(name: "Olive oil", amount: 15, unit: "mL", pantryKey: "olive_oil"), .init(name: "Lemon", amount: 1, unit: "whole", pantryKey: "none"), .init(name: "Spinach", amount: 100, unit: "g", pantryKey: "none")]
        }
        return [.init(name: "Salmon", amount: 2, unit: "fillets", pantryKey: "none"), .init(name: "Broccoli", amount: 1, unit: "head", pantryKey: "none"), .init(name: "Lemon", amount: 1, unit: "whole", pantryKey: "none"), .init(name: "Olive oil", amount: 15, unit: "mL", pantryKey: "olive_oil")]
    }
    var method: String { self == .bowl ? "Prepare the rice according to its package. Combine with chickpeas and spinach, and finish with lemon and oil." : "Prepare salmon safely according to food-safety guidance; cook with broccoli and finish with lemon and oil." }
}

struct DemoServicesView: View {
    var body: some View {
        List {
            Section {
                Text("Your demo, without the gates.").font(.title.bold())
                Text("Local mock pages for familiar services. No accounts, location, payment or external requests. These are not the real services or sponsored integrations.")
            }
            Section {
                NavigationLink { DemoSocialRecipesView() } label: { service("Instagram", subtitle: "Seeded recipe posts → save → groceries", icon: "camera", color: .pink) }
                NavigationLink { DemoMockCartView(recipe: .bowl) } label: { service("Instacart", subtitle: "Fictional pantry → exact net-new cart", icon: "basket", color: .green) }
                NavigationLink { DemoMockRideView() } label: { service("Uber", subtitle: "Prepare a ride to a fictional care visit", icon: "car.fill", color: .primary) }
            } header: { Text("Choose a journey") } footer: { Text("Mock service choices and receipts belong only to the selected demo member. Reset clears them. Real public recipe research remains available separately.") }
        }.navigationTitle("Demo services").demoLabel()
    }
    private func service(_ title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.title2).foregroundStyle(color).frame(width: 48, height: 54)
            VStack(alignment: .leading, spacing: 5) { Text(title + " · Mock").font(.headline); Text(subtitle).font(.callout).foregroundStyle(.secondary) }
        }.padding(.vertical, 10)
    }
}

struct DemoSocialRecipesView: View {
    @State private var demo = DemoSession.shared
    @State private var review: DemoMockRecipe?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Label("Instagram · Mock recipe feed", systemImage: "camera").font(.title2.bold())
                Text("Seeded posts and invented creators. No Instagram login, real posts or social activity.").font(.callout).foregroundStyle(.secondary)
                ForEach(DemoMockRecipe.allCases) { recipe in
                    VStack(alignment: .leading, spacing: 16) {
                        Label(recipe.creator, systemImage: "person.crop.circle").font(.headline)
                        ZStack {
                            RoundedRectangle(cornerRadius: 20).fill(recipe.color.opacity(0.12))
                            VStack(spacing: 14) { Image(systemName: recipe.symbol).font(.system(size: 72)); Text("WEEKDAY TABLE").font(.caption.weight(.bold)).tracking(3); Text(recipe.title).font(.title2.bold()).multilineTextAlignment(.center) }.padding(24).foregroundStyle(recipe.color)
                        }.frame(minHeight: 230).accessibilityLabel("Illustrated sample recipe: " + recipe.title)
                        Text("Two servings · Seeded demonstration recipe").font(.caption).foregroundStyle(.secondary)
                        Text(recipe.method)
                        DisclosureGroup("View exact sample ingredients") { ForEach(recipe.ingredients) { item in Text(item.summary).padding(.vertical, 4) } }
                        Button((demo.state.mockSavedRecipes ?? []).contains(recipe.rawValue) ? "Saved to demo recipes" : "Review saving this demo recipe") { review = recipe }.buttonStyle(.bordered).controlSize(.large).disabled((demo.state.mockSavedRecipes ?? []).contains(recipe.rawValue))
                        NavigationLink { DemoMockCartView(recipe: recipe) } label: { Label("Compare pantry & review groceries", systemImage: "basket") }.frame(minHeight: 44)
                        Button("Discuss this sample with Rumi") { demo.send("Discuss this seeded MOCK Instagram recipe, not a live post: \(recipe.title), two servings. Ingredients: \(recipe.ingredients.map(\.summary).joined(separator: "; ")). Offer practical meal planning, not clinical nutrition advice. Direct me to Demo services for reviewed mock groceries; do not claim saves or purchases.") }.frame(minHeight: 44)
                    }.padding(18).background(.background, in: RoundedRectangle(cornerRadius: 24))
                }
                if demo.busy { ProgressView("Live Rumi reply appears in chat") }
                if let error = demo.error { Text(error).foregroundStyle(.red) }
                Text("Return to chat to read Rumi’s live reply. The feed itself is seeded, not AI research.").font(.footnote)
            }.padding(20)
        }.background { AmbientBackground() }.navigationTitle("Recipe feed").demoLabel()
        .sheet(item: $review) { recipe in
            NavigationStack { Form {
                Section("Exact local save") { Text(recipe.title); Text("Mock source: Instagram-style feed / " + recipe.creator); ForEach(recipe.ingredients) { Text($0.summary) } }
                Section { Button("Confirm demo recipe save") {
                    guard !(demo.state.mockSavedRecipes ?? []).contains(recipe.rawValue) else { review = nil; return }
                    demo.update { $0.mockSavedRecipes = ($0.mockSavedRecipes ?? []) + [recipe.rawValue] }
                    demo.receipt("Simulated recipe saved locally: \(recipe.title). Seeded mock Instagram source; not fetched from Instagram.")
                    review = nil
                }.frame(minHeight: 44); Button("Cancel", role: .cancel) { review = nil }.frame(minHeight: 44) }
            }.navigationTitle("Review recipe").demoLabel() }
        }
    }
}

struct DemoMockCartView: View {
    let recipe: DemoMockRecipe
    @State private var demo = DemoSession.shared
    @State private var review = false
    @State private var exactItems: [DemoRecipeIngredient] = []
    @State private var cartSnapshot: [String] = []
    @State private var status: String?
    private func identity(_ item: DemoRecipeIngredient) -> String { item.pantryKey == "none" ? item.name.lowercased() : item.pantryKey }
    private var missing: [DemoRecipeIngredient] {
        let pantry: [String: Double] = ["chickpeas": 1, "brown_rice": 500, "olive_oil": 250]
        return recipe.ingredients.compactMap { item in
            let cart = (demo.state.cartQuantities ?? []).filter { identity($0) == identity(item) && $0.unit == item.unit }.reduce(0) { $0 + $1.amount }
            let amount = max(0, item.amount - (pantry[item.pantryKey] ?? 0) - cart)
            return amount > 0 ? .init(name: item.name, amount: amount, unit: item.unit, pantryKey: item.pantryKey) : nil
        }
    }
    private var uncertain: Bool {
        if !demo.state.cart.isEmpty && (demo.state.cartQuantities ?? []).isEmpty { return true }
        return recipe.ingredients.contains { item in (demo.state.cartQuantities ?? []).contains { identity($0) == identity(item) && $0.unit != item.unit } }
    }
    var body: some View {
        Form {
            Section {
                Label("Instacart · Mock store", systemImage: "basket.fill").font(.title2.bold()).foregroundStyle(.green)
                Text("Demo Market · No store account. No real prices, inventory, delivery or checkout.")
            }
            Section("Recipe · two servings") { Text(recipe.title); Text("Seeded mock recipe, not imported from a merchant.").font(.footnote); ForEach(recipe.ingredients) { Text($0.summary) } }
            Section("Fictional pantry") { Text("Chickpeas · 1 can\nBrown rice · 500 g\nOlive oil · 250 mL") }
            Section("Current demo cart") { if demo.state.cart.isEmpty { Text("Empty") }; ForEach(Array(demo.state.cart.enumerated()), id: \.offset) { Text($0.element) } }
            Section("Only what’s missing") {
                ForEach(missing) { Text($0.summary) }
                if uncertain { Text("Cart units need clarification. No update will be guessed.") }
                if missing.isEmpty { Text("Everything in this sample is covered by the pantry and demo cart.") }
                Button("Review exact demo cart update") { exactItems = missing; cartSnapshot = demo.state.cart; review = true }.buttonStyle(.borderedProminent).controlSize(.large).disabled(uncertain || missing.isEmpty)
                if let status { Text(status).font(.callout) }
            }
            Section { Text("Simulation only · No purchase or checkout").font(.headline); Text("This page can change only this member’s local demo cart.") }
        }.navigationTitle("Demo groceries").demoLabel()
        .sheet(isPresented: $review) {
            NavigationStack { Form {
                Section("Exact net-new additions") { ForEach(exactItems) { Text($0.summary) } }
                Section {
                    Button("Confirm local demo cart update") {
                        guard demo.state.cart == cartSnapshot, !uncertain, missing.map(\.summary) == exactItems.map(\.summary) else { status = "Cart changed. Review a fresh proposal."; review = false; return }
                        demo.update { $0.cart += exactItems.map(\.summary); $0.cartQuantities = ($0.cartQuantities ?? []) + exactItems }
                        demo.receipt("Simulated Instacart-style cart update: \(exactItems.map(\.summary).joined(separator: "; ")). Seeded source: \(recipe.title). No merchant or purchase.")
                        status = "Demo cart updated · No purchase"; review = false
                    }.frame(minHeight: 44)
                    Button("Cancel", role: .cancel) { review = false }.frame(minHeight: 44)
                } footer: { Text("Exact quantities for two sample servings. No payment, delivery or real store changes.") }
            }.navigationTitle("Before I continue").demoLabel() }
        }
    }
}

struct DemoMockRideView: View {
    @State private var demo = DemoSession.shared
    @State private var pickup = "Demo home · 100 Sample Lane"
    @State private var destination = "Demo primary care · 200 Example Avenue"
    @State private var vehicle = "Standard"
    @State private var review: String?
    var body: some View {
        Form {
            Section {
                Label("Uber · Mock ride planner", systemImage: "car.fill").font(.title2.bold())
                Text("No real locations, maps, fares, availability or drivers. Use fictional addresses only. No ride can be booked.")
            }
            Section("Sample route") {
                Label("Demo home", systemImage: "circle.circle").padding(.vertical, 8)
                Image(systemName: "ellipsis").rotationEffect(.degrees(90)).accessibilityHidden(true)
                Label("Fictional care visit", systemImage: "mappin.circle.fill").padding(.vertical, 8)
                TextField("Fictional pickup", text: $pickup)
                TextField("Fictional destination", text: $destination)
                Picker("Sample ride type", selection: $vehicle) { Text("Standard").tag("Standard"); Text("Roomier vehicle").tag("Roomier vehicle") }
                Text("Ride type is a sample choice, not an accessibility or transport suitability guarantee.").font(.footnote)
            }
            Section {
                Button("Review ride rehearsal") { review = "\(vehicle) · \(pickup.trimmingCharacters(in: .whitespacesAndNewlines)) → \(destination.trimmingCharacters(in: .whitespacesAndNewlines))" }.buttonStyle(.borderedProminent).controlSize(.large).disabled(pickup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pickup.count > 200 || destination.count > 200)
                Text("No payment details. No Book or Request action.").font(.footnote)
            }
            if let receipt = demo.state.mockRideReceipt { Section("Last rehearsal · not booked") { Text(receipt) } }
            Section { Text("For urgent medical help, use appropriate emergency services—not this mock ride planner.").font(.footnote) }
        }.navigationTitle("Ride rehearsal").demoLabel()
        .sheet(isPresented: Binding(get: { review != nil }, set: { if !$0 { review = nil } })) {
            NavigationStack { Form {
                Section("Exact rehearsal") { Text(review ?? ""); Text("Simulation only · No booking, driver or real appointment") }
                Section {
                    Button("Confirm unbooked demo rehearsal") {
                        guard let exact = review else { return }
                        demo.update { $0.mockRideReceipt = exact + " · Not booked" }
                        demo.receipt("Simulated Uber-style ride rehearsal: \(exact). Not booked; no network request or driver assignment.")
                        review = nil
                    }.frame(minHeight: 44)
                    Button("Cancel", role: .cancel) { review = nil }.frame(minHeight: 44)
                }
            }.navigationTitle("Review only").demoLabel() }
        }
    }
}
