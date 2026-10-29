import Foundation

nonisolated struct LiveSupportItem: Identifiable, Codable {
    struct Evidence: Codable {
        let id: String
        let text: String
    }
    let id: UUID
    let title: String
    let body: String
    let evidence: [Evidence]
    let kind: String
    let at: Date
}
