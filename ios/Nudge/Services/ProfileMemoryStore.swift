import Foundation

/// A finished conversation turn worth restoring on relaunch.
nonisolated struct SavedTurn: Codable, Equatable {
    let role: String
    let text: String
}

/// What Rumi remembers for one sample profile on this device.
nonisolated struct ProfileMemory: Codable {
    var memory: [MemoryItem] = []
    var turns: [SavedTurn] = []
}

/// One file per sample profile, inside this install's private container, so switching
/// profiles or other people using the same demo profile elsewhere never mixes memory.
nonisolated enum ProfileMemoryStore {
    private static func fileURL(_ pathway: String) -> URL {
        URL.documentsDirectory.appendingPathComponent("rumi_profile_\(pathway).json")
    }

    static func load(_ pathway: String) -> ProfileMemory? {
        guard let data = try? Data(contentsOf: fileURL(pathway)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ProfileMemory.self, from: data)
    }

    static func save(_ value: ProfileMemory, for pathway: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do { try encoder.encode(value).write(to: fileURL(pathway), options: .atomic) }
        catch { print("[Rumi] profile memory save failed: \(error.localizedDescription)") }
    }

    static func wipe(_ pathway: String) {
        try? FileManager.default.removeItem(at: fileURL(pathway))
    }

    static func wipeAll() {
        for pathway in CarePathway.allCases { wipe(pathway.rawValue) }
    }

    /// Drops in-progress and failed replies; keeps the latest 40 turns.
    static func restorable(_ turns: [ConversationTurn]) -> [SavedTurn] {
        turns.filter { !$0.streaming && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.text.hasPrefix("Live AI unavailable") }
            .suffix(40)
            .map { SavedTurn(role: $0.role == .user ? "user" : "companion", text: $0.text) }
    }
}
