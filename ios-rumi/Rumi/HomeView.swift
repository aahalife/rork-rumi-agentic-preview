//
//  HomeView.swift
//  Rumi
//

import SwiftUI

// MARK: - Chat (primary surface)

struct HomeView: View {
    @State private var store = ChatStore()
    @State private var works = WorksModel()
    @State private var showingWorks = false
    @State private var showingRecipes = false
    @State private var menuDestination: String?
    @State private var openRecipeAfterDismiss = false
    @State private var draft = ""
    @State private var attachments: [ChatAttachment] = []
    @State private var editingMessageID: UUID?
    @FocusState private var composerFocused: Bool

    @State private var showingMenu = false
    @State private var showingVoice = false
    @State private var showingChatConsent = false
    @AppStorage("rumi.chat-processing.consent.v1") private var chatConsent = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var toast: String?

    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    @State private var isAtBottom = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Button { composerFocused = false; showingWorks = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                        VStack(alignment: .leading, spacing: 3) {
                            Text(works.hasActivity ? "Return to Rumi Works" : "Explore with Rumi Works").font(.rumiSubheadline.weight(.semibold))
                            Text(works.hasActivity ? works.control.rawValue : "Browse websites, recipes & groceries").font(.rumiCaption1).foregroundStyle(Color.labelSecondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }.padding(14).glassCard(cornerRadius: 20)
                }.buttonStyle(.plain).foregroundStyle(Color.brandPrimary).padding(.horizontal, .screenMargin)
                transcript
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { AmbientBackground() }
            .navigationTitle("Rumi")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingMenu = true
                    } label: {
                        // Stock toolbar button; iOS 26 renders it in a native glass circle.
                        Image(systemName: "line.3.horizontal")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                ChatComposer(
                    text: $draft,
                    attachments: $attachments,
                    editingMessageID: editingMessageID,
                    isResponding: store.isResponding,
                    isFocused: $composerFocused,
                    onSend: send,
                    onStop: { store.stop() },
                    onCancelEdit: cancelEdit,
                    onVoice: { showingVoice = true }
                )
            }
            .sheet(isPresented: $showingMenu, onDismiss: {
                if menuDestination == "works" { showingWorks = true }
                if menuDestination == "recipes" { showingRecipes = true }
                menuDestination = nil
            }) {
                MenuView(openWorks: {
                    menuDestination = "works"
                    showingMenu = false
                }, openRecipes: {
                    menuDestination = "recipes"
                    showingMenu = false
                })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .fullScreenCover(isPresented: $showingWorks) { WorksView(model: works) }
            .sheet(isPresented: $showingRecipes, onDismiss: {
                if openRecipeAfterDismiss { showingWorks = true; openRecipeAfterDismiss = false }
            }) {
                NavigationStack {
                    WorksRecipesView(model: works, onOpen: {
                        openRecipeAfterDismiss = true
                        showingRecipes = false
                    })
                }
            }
            .fullScreenCover(isPresented: $showingVoice) { VoiceModeView() }
            .alert("Chat with Rumi’s AI service?", isPresented: $showingChatConsent) {
                Button("Continue") { chatConsent = true; send() }
                Button("Not now", role: .cancel) { }
            } message: {
                Text("Your messages are sent to your configured AI service and stored as your conversation. If you link iMessage, that verified conversation shares this history. You can disconnect this device in Account.")
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RumiDemoWillEnter"))) { _ in
                store.stop(); works.takeControl()
            }
            .onChange(of: CompanionConnection.shared.identityVersion) { _, _ in
                store.stop(); store = ChatStore(); works.takeControl()
            }
            .task {
                while !Task.isCancelled {
                    if scenePhase == .active, editingMessageID == nil, !DemoSession.shared.isPresented { await store.sync() }
                    do { try await Task.sleep(for: .seconds(15)) } catch { return }
                }
            }
        }
    }

    // MARK: Transcript

    private var transcript: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(store.messages) { message in
                    switch message.role {
                    case .user:
                        UserMessageRow(
                            message: message,
                            isBeingEdited: editingMessageID == message.id,
                            onEdit: { beginEdit(message) },
                            onCopy: { copy(message.text) }
                        )
                    case .assistant:
                        AssistantMessageRow(
                            message: message,
                            onFeedback: { feedback in
                                store.setFeedback(feedback, for: message.id)
                                if feedback != nil { showToast("Thanks for your feedback") }
                            },
                            onCopy: { copy(message.text) },
                            onShare: {
                                SharePresenter.share(message.text) { completed in
                                    if completed { showToast("Shared") }
                                }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, .screenMargin)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollPosition($scrollPosition)
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.visibleRect.maxY >= geometry.contentSize.height - 60
        } action: { _, atBottom in
            withAnimation(.easeOut(duration: 0.2)) { isAtBottom = atBottom }
        }
        // Follow streamed text while the reader is at the bottom.
        .onChange(of: store.contentVersion) {
            if isAtBottom { scrollPosition.scrollTo(edge: .bottom) }
        }
        .overlay(alignment: .bottom) {
            ZStack {
                if let toast {
                    SuccessToast(message: toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: toast) {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { self.toast = nil }
                        }
                } else if !isAtBottom {
                    Button {
                        withAnimation(.smooth) { scrollPosition.scrollTo(edge: .bottom) }
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.rumiBody.weight(.semibold))
                            .foregroundStyle(Color.labelPrimary)
                            .frame(width: 40, height: 40)
                            .glassEffect(.regular.interactive(), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Scroll to latest message")
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: Actions

    private func send() {
        if !chatConsent { composerFocused = false; showingChatConsent = true; return }
        if let id = editingMessageID {
            store.edit(id, to: draft)
            editingMessageID = nil
        } else {
            store.send(draft, attachments: attachments)
            attachments = []
        }
        draft = ""
        withAnimation(.smooth) { scrollPosition.scrollTo(edge: .bottom) }
    }

    private func beginEdit(_ message: ChatMessage) {
        editingMessageID = message.id
        draft = message.text
        composerFocused = true
    }

    private func cancelEdit() {
        editingMessageID = nil
        draft = ""
        composerFocused = false
    }

    private func copy(_ text: String) {
        UIPasteboard.general.string = text
        showToast("Copied to clipboard")
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { toast = message }
    }
}

// MARK: - Menu (secondary surface)

private struct MenuView: View {
    let openWorks: () -> Void
    let openRecipes: () -> Void
    @State private var showingDemo = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Button { showingDemo = true } label: { menuRow("Explore demo members", icon: .user) }
                        .buttonStyle(GlassRowButtonStyle())
                    GlassDivider()
                    Button(action: openWorks) { menuRow("Rumi Works", icon: .sparkles) }
                        .buttonStyle(GlassRowButtonStyle())
                    GlassDivider()
                    Button(action: openRecipes) { menuRow("My recipes", icon: .clipboardList) }
                        .buttonStyle(GlassRowButtonStyle())
                    GlassDivider()
                    NavigationLink {
                        HealthView(onClose: { dismiss() })
                    } label: {
                        menuRow("Health", icon: .heart)
                    }
                    .buttonStyle(GlassRowButtonStyle())

                    GlassDivider()

                    NavigationLink {
                        CompanionAccountView()
                    } label: {
                        menuRow("Account", icon: .user)
                    }
                    .buttonStyle(GlassRowButtonStyle())
                }
                .glassCard()
                .padding(.horizontal, .screenMargin)
                .padding(.top, 16)
            }
            .background { ScreenBackground() }
            .fullScreenCover(isPresented: $showingDemo) { DemoEntryView() }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Native iOS 26 close button (system xmark glyph).
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func menuRow(_ title: String, icon: FAIcon) -> some View {
        HStack(spacing: 14) {
            FAIconView(icon: icon)
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 24)
            Text(title)
                .font(.rumiBody)
            Spacer(minLength: 8)
            RowChevron()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

// MARK: - Placeholder sections

struct EmptyTabView: View {
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Text(title)
                .font(.rumiTitle1)
                .foregroundStyle(Color.labelPrimary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { ScreenBackground() }
    }
}

#Preview {
    HomeView()
}
