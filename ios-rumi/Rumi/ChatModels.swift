//
//  ChatModels.swift
//  Rumi
//
//  Chat data model, transcript store, and the swappable reply generator.
//

import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

// MARK: - Attachments

struct ChatAttachment: Identifiable, Equatable {
    enum Kind { case image, video, file }

    let id = UUID()
    let kind: Kind
    /// Preview image for photos and videos.
    let thumbnail: UIImage?
    /// Local copy of the picked file (videos and documents).
    let fileURL: URL?
    let name: String
    /// Secondary line for file chips, e.g. "PDF · 1.2 MB".
    let detail: String

    static func == (lhs: ChatAttachment, rhs: ChatAttachment) -> Bool { lhs.id == rhs.id }

    /// SF Symbol for a document, based on its type.
    var fileSymbol: String {
        guard let ext = fileURL?.pathExtension, let type = UTType(filenameExtension: ext) else {
            return "doc"
        }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .audio) { return "waveform" }
        if type.conforms(to: .movie) { return "film" }
        if type.conforms(to: .spreadsheet) { return "tablecells" }
        if type.conforms(to: .presentation) { return "rectangle.on.rectangle" }
        if type.conforms(to: .archive) { return "doc.zipper" }
        if type.conforms(to: .text) { return "doc.text" }
        return "doc"
    }
}

// MARK: - Messages

struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }
    enum Feedback { case up, down }

    let id: UUID
    let role: Role
    var text: String
    var attachments: [ChatAttachment]
    var isStreaming: Bool
    var feedback: Feedback?
    var isEdited: Bool
    var serviceID: String? = nil

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        attachments: [ChatAttachment] = [],
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.attachments = attachments
        self.isStreaming = isStreaming
        self.feedback = nil
        self.isEdited = false
    }

    /// Waiting on the first token of a reply.
    var isThinking: Bool { role == .assistant && isStreaming && text.isEmpty }
}

// MARK: - Store

@Observable
final class ChatStore {
    private(set) var messages: [ChatMessage] = []
    /// Bumps whenever transcript content changes, so the view can follow the latest text.
    private(set) var contentVersion = 0

    private let generator: ReplyGenerator
    private var generationTask: Task<Void, Never>?

    init(generator: ReplyGenerator = CompanionReplyGenerator()) {
        self.generator = generator
    }

    var isResponding: Bool { messages.last?.isStreaming == true }

    func send(_ text: String, attachments: [ChatAttachment]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !attachments.isEmpty else { return }
        stop()
        messages.append(ChatMessage(role: .user, text: trimmed, attachments: attachments))
        generateReply()
    }

    /// Replaces a sent message and regenerates everything after it.
    func edit(_ id: UUID, to text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        guard !trimmed.isEmpty || !messages[index].attachments.isEmpty else { return }
        stop()
        messages[index].text = trimmed
        messages[index].isEdited = true
        messages.removeSubrange((index + 1)...)
        generateReply()
    }

    func stop() {
        generationTask?.cancel()
        generationTask = nil
        guard let last = messages.indices.last, messages[last].isStreaming else { return }
        if messages[last].text.isEmpty {
            messages.removeLast()
        } else {
            messages[last].isStreaming = false
        }
        contentVersion += 1
    }

    func setFeedback(_ feedback: ChatMessage.Feedback?, for id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].feedback = feedback
    }

    func sync() async {
        guard !isResponding, CompanionConnection.shared.connected else { return }
        do {
            let remote: RemoteConversation = try await CompanionConnection.shared.request("messages")
            guard !isResponding else { return }
            let old = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0) })
            messages = remote.messages.map { entry in
                let hash = SHA256.hash(data: Data(entry.id.utf8)).map { String(format: "%02x", $0) }.joined()
                let part = String(hash.prefix(32))
                let formatted = "\(part.prefix(8))-\(part.dropFirst(8).prefix(4))-\(part.dropFirst(12).prefix(4))-\(part.dropFirst(16).prefix(4))-\(part.dropFirst(20))"
                let id = UUID(uuidString: entry.id) ?? UUID(uuidString: formatted)!
                var item = old[id] ?? ChatMessage(id: id, role: entry.role == "user" ? .user : .assistant, text: entry.text)
                item.text = entry.text; item.serviceID = entry.id
                return item
            }
            contentVersion += 1
        } catch { /* Keep the current transcript on a failed background refresh. Requests show errors on send. */ }
    }

    private func generateReply() {
        let history = messages
        let prompt = history.last?.text ?? ""
        let reply = ChatMessage(role: .assistant, text: "", isStreaming: true)
        let replyID = reply.id
        messages.append(reply)
        contentVersion += 1

        generationTask = Task { [weak self, generator] in
            do {
                if history.last?.attachments.isEmpty == false { throw CompanionError(message: "Attachment analysis isn’t connected yet. Please paste the relevant text, or open the source in Rumi Works.") }
                for try await chunk in generator.streamReply(to: prompt, history: history) {
                    guard let self, !Task.isCancelled else { return }
                    guard let index = self.messages.firstIndex(where: { $0.id == replyID }) else { return }
                    self.messages[index].text += chunk
                    self.contentVersion += 1
                }
            } catch {
                guard let self, !Task.isCancelled, let index = self.messages.firstIndex(where: { $0.id == replyID }) else { return }
                self.messages[index].text = error.localizedDescription
                self.contentVersion += 1
            }
            guard let self, !Task.isCancelled,
                  let index = self.messages.firstIndex(where: { $0.id == replyID }) else { return }
            self.messages[index].isStreaming = false
            self.contentVersion += 1
        }
    }
}

// MARK: - Reply generation

/// Swap point for the real AI service: return a stream of text chunks for the reply.
/// Latency before the first chunk is shown as the thinking state.
protocol ReplyGenerator {
    func streamReply(to prompt: String, history: [ChatMessage]) -> AsyncThrowingStream<String, Error>
}

struct CompanionReplyGenerator: ReplyGenerator {
    func streamReply(to prompt: String, history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    struct Reply: Decodable { let text: String }
                    let id = history.last?.serviceID ?? history.last?.id.uuidString ?? UUID().uuidString
                    let reply: Reply = try await CompanionConnection.shared.request("chat", body: ["text": prompt, "id": id])
                    try Task.checkCancellation()
                    continuation.yield(reply.text); continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Kept only for isolated design previews, never selected by the app.
struct FillerReplyGenerator: ReplyGenerator {
    func streamReply(to prompt: String, history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        let text = FillerProse.reply()
        return AsyncThrowingStream { continuation in
            let task = Task {
                // Thinking time before the first token.
                try? await Task.sleep(for: .milliseconds(Int.random(in: 900...1800)))
                for chunk in FillerProse.chunks(of: text) {
                    if Task.isCancelled { break }
                    continuation.yield(chunk)
                    let pause = chunk.hasSuffix(". ") || chunk.hasSuffix("\n") ? 160...280 : 25...75
                    try? await Task.sleep(for: .milliseconds(Int.random(in: pause)))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

enum FillerProse {
    private static let openers = [
        "In most cases,", "Generally speaking,", "From what you've described,", "It's worth noting that",
        "One way to look at it is that", "Broadly,", "Over time,", "In practice,", "More often than not,",
        "Looking at the bigger picture,"
    ]
    private static let subjects = [
        "the overall pattern", "your baseline", "the underlying rhythm", "this kind of shift",
        "the broader picture", "a steady routine", "the day-to-day signal", "that combination of factors",
        "the earlier trend", "small, consistent changes", "the way you're approaching it", "the middle stretch"
    ]
    private static let verbs = [
        "tends to settle into", "often reflects", "can gradually shape", "usually points toward",
        "may quietly influence", "typically balances out against", "lines up closely with", "builds on",
        "sits comfortably within", "gives a clearer view of"
    ]
    private static let objects = [
        "the way things unfold over a few weeks", "how the rest of the week goes", "the context around it",
        "a more stable middle ground", "what happens later in the day", "the habits that surround it",
        "a clearer sense of direction", "the range you'd normally expect", "the things you already do well",
        "a slower, steadier pace"
    ]
    private static let tails = [
        "", "", " rather than any single moment", ", especially when things stay consistent",
        ", though it varies from person to person", " once the initial noise fades",
        ", which is usually a good sign", " without much extra effort"
    ]
    private static let shorts = [
        "That's a reasonable place to start.", "Context matters here.", "It's a gradual process.",
        "Nothing here is unusual on its own.", "That part is fairly common.", "There's no single right answer.",
        "It helps to keep it simple."
    ]
    private static let questions = [
        "Have you noticed whether it changes on busier days?",
        "Would it help to look at how this has moved over the last month?",
        "Is there a particular part of this you'd like to dig into?",
        "Does that match what you've been seeing?",
        "Want me to break that down a little further?"
    ]
    private static let labels = ["Consistency", "Timing", "Context", "Recovery", "Rest", "Pacing", "Balance", "Routine"]
    private static let fragments = [
        "keep an eye on how it feels across a full week", "small adjustments tend to add up",
        "it's easier to notice changes when the baseline is steady", "look for patterns rather than single days",
        "give it a little time before drawing conclusions", "pair it with something you already do",
        "notice what tends to come right before it"
    ]

    static func reply() -> String {
        var paragraphs: [String] = []
        let shape = Int.random(in: 0..<10)
        let paragraphCount = shape < 3 ? 1 : (shape < 8 ? 2 : 3)

        for index in 0..<paragraphCount {
            let count = paragraphCount == 1 ? Int.random(in: 1...3) : Int.random(in: 2...4)
            var sentences = (0..<count).map { _ in sentence() }
            if index == 0, Bool.random() { sentences.insert(shorts.randomElement()!, at: 0) }
            paragraphs.append(sentences.joined(separator: " "))

            // Occasionally a short list, the way a real answer might structure things.
            if index == 0, paragraphCount > 1, Int.random(in: 0..<4) == 0 {
                let items = labels.shuffled().prefix(3).map { "• **\($0)** — \(fragments.randomElement()!)" }
                paragraphs.append(items.joined(separator: "\n"))
            }
        }

        if Int.random(in: 0..<3) == 0 { paragraphs.append(questions.randomElement()!) }
        return paragraphs.joined(separator: "\n\n")
    }

    /// Short single-line caption, used by the voice mode demo.
    static func shortReply() -> String {
        (0..<Int.random(in: 1...2)).map { _ in sentence() }.joined(separator: " ")
    }

    private static func sentence() -> String {
        switch Int.random(in: 0..<10) {
        case 0..<4:
            return "\(openers.randomElement()!) \(subjects.randomElement()!) \(verbs.randomElement()!) \(objects.randomElement()!)\(tails.randomElement()!)."
        case 4..<7:
            return "\(subjects.randomElement()!.capitalizedFirst) \(verbs.randomElement()!) \(objects.randomElement()!)\(tails.randomElement()!)."
        case 7..<9:
            let first = subjects.randomElement()!
            let second = subjects.filter { $0 != first }.randomElement()!
            let joiner = Bool.random() ? ", and" : ", but"
            return "\(first.capitalizedFirst) \(verbs.randomElement()!) \(objects.randomElement()!)\(joiner) \(second) \(verbs.randomElement()!) \(objects.randomElement()!)."
        default:
            return shorts.randomElement()!
        }
    }

    /// Splits text into 1–3 word chunks, keeping whitespace and newlines intact.
    static func chunks(of text: String) -> [String] {
        var words: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character == " " || character == "\n" {
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty { words.append(current) }

        var chunks: [String] = []
        var index = 0
        while index < words.count {
            let size = min(Int.random(in: 1...3), words.count - index)
            chunks.append(words[index..<(index + size)].joined())
            index += size
        }
        return chunks
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
