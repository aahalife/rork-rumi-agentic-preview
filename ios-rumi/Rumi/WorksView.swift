import SwiftUI

struct WorksView: View {
    @Bindable var model: WorksModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft = ""
    @State private var address = ""
    @State private var showRecipes = false
    @State private var clearData = false
    @State private var showContextConsent = false
    @AppStorage("rumi.page-context.consent.v1") private var contextConsent = false
    @FocusState private var focused: Bool
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 8) {
                    browserHeader
                    ZStack(alignment: .bottom) {
                        WorksBrowser(model: model)
                        if let error = model.browserError {
                            VStack(spacing: 8) {
                                Text(error).font(.rumiFootnote)
                                Button("Reload page") { model.reload() }.frame(minHeight: 44)
                            }.padding().frame(maxWidth: .infinity).background(.regularMaterial)
                        }
                    }
                    .frame(height: model.expanded ? (model.browserOnly ? nil : max(120, geometry.size.height * 0.55)) : 0)
                    .frame(maxHeight: model.browserOnly ? .infinity : nil)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.brandPrimary.opacity(0.2)))
                    .accessibilityHidden(!model.expanded)
                    statusControls
                    if !model.browserOnly { conversation }
                }.padding(.horizontal, 12).padding(.top, 6)
            }
            .background { AmbientBackground() }
            .navigationTitle("Rumi Works").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("My recipes", systemImage: "book") { showRecipes = true }
                        Button("Clear website sign-ins & data", systemImage: "lock.rotation", role: .destructive) { clearData = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Minimize") { focused = false; model.pause(); dismiss() } }
            }
            .safeAreaInset(edge: .bottom) { if !model.browserOnly { composer } }
            .sheet(isPresented: $model.reviewPresented) { approval }
            .sheet(isPresented: $showRecipes) { NavigationStack { WorksRecipesView(model: model) } }
            .confirmationDialog("Clear all website sign-ins?", isPresented: $clearData, titleVisibility: .visible) {
                Button("Clear website data", role: .destructive) { model.clearWebsiteData() }
            } message: { Text("You’ll need to sign in to websites again. Saved recipe sources will stay.") }
            .confirmationDialog("Share this page with Rumi’s AI service?", isPresented: $showContextConsent, titleVisibility: .visible) {
                Button("Allow page context") { contextConsent = true; send() }
                Button("Ask without the page") { model.includeContext = false; send() }
            } message: { Text("Selected website text and, when needed, a masked page image are sent to your configured AI service. This may include private health information. Password and security fields are excluded. You can turn page context off at any time.") }
            .onChange(of: scenePhase) { _, phase in if phase != .active { model.pause() } }
            .onAppear { address = model.address }
            .onChange(of: model.address) { _, value in address = value }
        }.tint(.brandPrimary)
    }
    private var browserHeader: some View {
        HStack(spacing: 4) {
            Button { model.back() } label: { Image(systemName: "chevron.left").frame(width: 32, height: 44) }.disabled(!model.canGoBack).accessibilityLabel("Back")
            Button { model.forward() } label: { Image(systemName: "chevron.right").frame(width: 28, height: 44) }.disabled(!model.canGoForward).accessibilityLabel("Forward")
            TextField("Website address", text: $address)
                .font(.rumiFootnote).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).submitLabel(.go)
                .onSubmit { model.navigate(address) }.padding(9).background(.thinMaterial, in: Capsule())
                .accessibilityLabel("Website address")
            if model.loading { ProgressView().controlSize(.mini) }
            Button { model.reload() } label: { Image(systemName: "arrow.clockwise").frame(width: 28, height: 44) }.accessibilityLabel("Reload website")
            Button {
                model.expanded = true; model.browserOnly.toggle(); focused = false
            } label: { Image(systemName: model.browserOnly ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right").frame(width: 32, height: 44) }.accessibilityLabel(model.browserOnly ? "Show conversation" : "Full browser")
        }.foregroundStyle(Color.brandPrimary)
    }
    private var statusControls: some View {
        HStack(spacing: 8) {
            Circle().fill(model.control == .review ? Color.orange : Color.brandPrimary).frame(width: 7, height: 7)
            Text(model.control.rawValue).font(.rumiCaption1.weight(.semibold)).lineLimit(1)
            Spacer(minLength: 0)
            if model.control == .working {
                Button("Take control") { model.takeControl() }
                Button("Pause") { model.pause() }
            } else if model.control == .paused { Button("Resume") { model.resume() } }
            if model.control == .working || model.control == .paused { Button("Stop") { model.stop() } }
        }.font(.rumiCaption1).frame(minHeight: 36)
    }
    private var conversation: some View {
        VStack(spacing: 4) {
            if model.pending != nil {
                Button { focused = false; model.reviewPresented = true } label: {
                    Label("Review next action", systemImage: "hand.raised").font(.rumiFootnote.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                }.background(Color.alertWarningFill.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(model.messages) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message.user ? "You" : "Rumi").font(.rumiCaption1.weight(.semibold)).foregroundStyle(Color.brandPrimary)
                                Text(message.text).font(.rumiSubheadline).textSelection(.enabled)
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(message.user ? Color.brandSecondaryTint.opacity(0.65) : Color.fillPrimary.opacity(0.65), in: RoundedRectangle(cornerRadius: 18)).id(message.id)
                        }
                    }.padding(.vertical, 4)
                }.scrollDismissesKeyboard(.interactively)
                    .onChange(of: model.messages.count) { _, _ in if let id = model.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) } }
            }
        }
    }
    private var composer: some View {
        VStack(spacing: 8) {
            Toggle(isOn: Binding(get: { model.includeContext }, set: { model.takeControl(); model.includeContext = $0 })) {
                Label(model.includeContext ? model.pageTitle : "Page context off", systemImage: "doc.text.magnifyingglass").font(.rumiCaption1).lineLimit(1)
            }.toggleStyle(.switch).controlSize(.mini)
            HStack(alignment: .bottom) {
                TextField("Ask Rumi to help with this page…", text: $draft, axis: .vertical).lineLimit(1...3).focused($focused).submitLabel(.send).onSubmit(send)
                Button(action: send) {
                    Image(systemName: "arrow.up").font(.rumiHeadline).foregroundStyle(.white).frame(width: 44, height: 44).background(Color.brandPrimary, in: Circle())
                }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel("Ask Rumi")
            }.padding(10).glassCard(cornerRadius: 26)
        }.padding(.horizontal, 16).padding(.vertical, 10).background(.regularMaterial)
    }
    private func send() {
        if model.includeContext && !contextConsent { focused = false; showContextConsent = true; return }
        model.ask(draft); draft = ""; focused = false
    }
    @ViewBuilder private var approval: some View {
        if let proposal = model.pending {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Before I continue").font(.rumiTitle2.weight(.semibold))
                    Text("Review this exact action and the current page. Editing or navigating cancels this approval.").font(.rumiSubheadline)
                    ScrollView { Text(proposal.summary).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).padding().glassCard() }
                    HStack {
                        Button("Decline", role: .destructive) { model.decline() }.frame(maxWidth: .infinity, minHeight: 48)
                        Button("Approve this action") { model.approve(proposal) }.buttonStyle(.borderedProminent).frame(minHeight: 48)
                    }
                    Button("Edit the page first") { model.takeControl() }.frame(minHeight: 44)
                    Button("Review later · keep paused") { model.reviewPresented = false }.frame(maxWidth: .infinity, minHeight: 44)
                }.padding(20).background { AmbientBackground() }
            }.presentationDetents([.large])
        }
    }
}

struct WorksRecipesView: View {
    @Bindable var model: WorksModel
    @Environment(\.dismiss) private var dismiss
    var onOpen: (() -> Void)? = nil
    var body: some View {
        List {
            Section {
                ForEach(model.saved) { recipe in
                    DisclosureGroup {
                        Text(recipe.ingredients.isEmpty ? "No ingredient quantities were available on this page." : recipe.ingredients).font(.rumiSubheadline).textSelection(.enabled)
                        Button("Open source") { model.openRecipe(recipe); dismiss(); onOpen?() }
                        ShareLink("Share ingredients", item: "\(recipe.title)\n\(recipe.url)\n\n\(recipe.ingredients)")
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.title).font(.rumiHeadline)
                            Text(URL(string: recipe.url)?.host ?? recipe.url).font(.rumiFootnote).foregroundStyle(Color.labelSecondary)
                        }.padding(.vertical, 6)
                    }.swipeActions { Button("Remove", role: .destructive) { model.removeRecipe(recipe.id) } }
                }
                if model.saved.isEmpty { Text("Ask Rumi to save a recipe while viewing its website.").foregroundStyle(Color.labelSecondary) }
            } footer: { Text("Saved on this device with their source. Check extracted quantities against the original recipe. Tell Rumi what’s at home before comparing your actual grocery cart.") }
        }.scrollContentBackground(.hidden).background { AmbientBackground() }.navigationTitle("My recipes")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
    }
}
