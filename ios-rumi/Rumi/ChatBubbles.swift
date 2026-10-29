//
//  ChatBubbles.swift
//  Rumi
//
//  Message rows: user bubble (with edit), assistant bubble (streamed),
//  thinking pill, and reply feedback actions.
//
//  Bubble corners mirror each other:
//  - AI: 6pt top-left (tail), 22pt on the other three corners.
//  - User: 6pt top-right (tail), 22pt on the other three corners.
//

import SwiftUI

// MARK: - Shared bubble tokens

enum ChatBubble {
    static let maxWidth: CGFloat = 318
    static let tailRadius: CGFloat = 6
    static let radius: CGFloat = 22

    /// Tail on the top-left.
    static let assistantShape = UnevenRoundedRectangle(
        topLeadingRadius: tailRadius,
        bottomLeadingRadius: radius,
        bottomTrailingRadius: radius,
        topTrailingRadius: radius,
        style: .continuous
    )

    /// Tail on the top-right.
    static let userShape = UnevenRoundedRectangle(
        topLeadingRadius: radius,
        bottomLeadingRadius: radius,
        bottomTrailingRadius: radius,
        topTrailingRadius: tailRadius,
        style: .continuous
    )
}

private extension View {
    /// Frosted white fill, 1pt white border, and the same two-layer elevation-1 shadow as `.glassCard()`.
    func frostedBubble<S: InsettableShape>(_ shape: S) -> some View {
        background {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(Color.fillPrimary.opacity(0.5)))
                .shadow(color: Color.brandPrimaryShade.opacity(0.02), radius: 5, x: 0, y: 0)
                .shadow(color: Color.brandPrimaryShade.opacity(0.04), radius: 2.5, x: 0, y: 2)
        }
        .overlay { shape.strokeBorder(Color.fillPrimary, lineWidth: 1) }
    }
}

// MARK: - User message

struct UserMessageRow: View {
    let message: ChatMessage
    let isBeingEdited: Bool
    let onEdit: () -> Void
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if !message.attachments.isEmpty {
                attachmentGrid
            }

            if !message.text.isEmpty {
                Text(message.text)
                    .font(.rumiBody) // 17 / 22
                    .foregroundStyle(Color.labelPrimaryContrast)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.brandPrimaryShade, in: ChatBubble.userShape)
                    .opacity(isBeingEdited ? 0.55 : 1)
                    .contentShape(.contextMenuPreview, ChatBubble.userShape)
                    .contextMenu {
                        Button("Edit", systemImage: "pencil", action: onEdit)
                        Button("Copy", systemImage: "doc.on.doc", action: onCopy)
                    }
                    .frame(maxWidth: ChatBubble.maxWidth, alignment: .trailing)
            }

            if message.isEdited {
                Text("Edited")
                    .font(.rumiCaption1)
                    .foregroundStyle(Color.labelTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Edit", onEdit)
    }

    private var attachmentGrid: some View {
        let media = message.attachments.filter { $0.kind != .file }
        let files = message.attachments.filter { $0.kind == .file }
        return VStack(alignment: .trailing, spacing: 6) {
            ForEach(Array(stride(from: 0, to: media.count, by: 3)), id: \.self) { start in
                HStack(spacing: 6) {
                    ForEach(media[start..<min(start + 3, media.count)]) { item in
                        AttachmentPreview(attachment: item, size: media.count == 1 ? 180 : 96)
                    }
                }
            }
            ForEach(files) { file in
                AttachmentPreview(attachment: file, size: 56)
            }
        }
    }
}

// MARK: - Assistant message

struct AssistantMessageRow: View {
    let message: ChatMessage
    let onFeedback: (ChatMessage.Feedback?) -> Void
    let onCopy: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if message.isThinking {
                ThinkingIndicator()
                    .transition(.opacity)
            } else {
                Text(Self.render(message.text))
                    .font(.rumiBody) // 17 / 22
                    .foregroundStyle(Color.labelPrimary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frostedBubble(ChatBubble.assistantShape)
                    .frame(maxWidth: ChatBubble.maxWidth, alignment: .leading)
            }

            // AI-only affordance.
            if !message.isStreaming && !message.text.isEmpty {
                actions
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.25), value: message.isStreaming)
        .animation(.easeOut(duration: 0.2), value: message.isThinking)
    }

    private var actions: some View {
        HStack(spacing: 4) {
            actionButton(
                message.feedback == .up ? "hand.thumbsup.fill" : "hand.thumbsup",
                label: "Good response",
                isSelected: message.feedback == .up
            ) {
                onFeedback(message.feedback == .up ? nil : .up)
            }
            actionButton(
                message.feedback == .down ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                label: "Bad response",
                isSelected: message.feedback == .down
            ) {
                onFeedback(message.feedback == .down ? nil : .down)
            }
            actionButton("doc.on.doc", label: "Copy", isSelected: false, action: onCopy)
            actionButton("square.and.arrow.up", label: "Share", isSelected: false, action: onShare)
        }
        .padding(.leading, -8)
        .sensoryFeedback(.selection, trigger: message.feedback)
    }

    private func actionButton(
        _ symbol: String,
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.rumiSubheadline)
                .foregroundStyle(isSelected ? Color.brandPrimary : Color.labelTertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Inline markdown (bold) with paragraph breaks preserved.
    static func render(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

// MARK: - Thinking pill

struct ThinkingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            // 32pt box, 24pt ellipsis glyph with a looping left-to-right sweep across the dots.
            TimelineView(.animation(paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let progress = reduceMotion ? 0.5 : (t.truncatingRemainder(dividingBy: 1.2) / 1.2)
                FAIconView(icon: .ellipsis, size: 24)
                    .foregroundStyle(Color.labelQuaternary.opacity(0.35))
                    .overlay {
                        FAIconView(icon: .ellipsis, size: 24)
                            .foregroundStyle(Color.brandPrimary)
                            .mask {
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: progress - 0.35),
                                        .init(color: .black, location: progress),
                                        .init(color: .clear, location: progress + 0.35)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                    }
            }
            .frame(width: 32, height: 32)

            Text("Thinking...")
                .font(.rumiCallout) // 16 / 21
                .foregroundStyle(Color.labelQuaternary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frostedBubble(ChatBubble.assistantShape)
        .accessibilityElement()
        .accessibilityLabel("Rumi is thinking")
    }
}

// MARK: - Native share sheet

enum SharePresenter {
    /// Presents UIActivityViewController; completion reports whether an activity finished.
    static func share(_ text: String, completion: @escaping (Bool) -> Void) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard let root = scene?.keyWindow?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }

        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            Task { @MainActor in completion(completed) }
        }
        if let popover = controller.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        top.present(controller, animated: true)
    }
}
