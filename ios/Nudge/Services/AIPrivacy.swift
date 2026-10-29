import Foundation
import Observation

/// Local AI choices. Both are on by default; an explicit "off" is remembered.
/// The Anthropic key lives only on the server and is never stored on the device.
@Observable final class AIPrivacy {
    var processingConsent: Bool = UserDefaults.standard.object(forKey: "rumi.ai.consent") as? Bool ?? true {
        didSet { UserDefaults.standard.set(processingConsent, forKey: "rumi.ai.consent") }
    }
    var memoryConsent: Bool = UserDefaults.standard.object(forKey: "rumi.ai.memory") as? Bool ?? true {
        didSet { UserDefaults.standard.set(memoryConsent, forKey: "rumi.ai.memory") }
    }

    /// Random per-install ID. Separates this phone's rate limits from other people using the
    /// same demo profile; it carries no personal data.
    let deviceID: String = AIPrivacy.loadOrCreateDeviceID()

    private static func loadOrCreateDeviceID() -> String {
        let account = "rumi-device-id"
        if let saved = KeychainStore.load(account: account), saved.count >= 20 { return saved }
        let fresh = UUID().uuidString
        try? KeychainStore.save(fresh, account: account)
        return fresh
    }
}
