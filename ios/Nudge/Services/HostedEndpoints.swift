import Foundation

/// Public endpoints from the browser-agent repository. Invitation codes are never bundled.
nonisolated enum HostedEndpoints {
    static let portal = URL(string: "https://3pxarh5thg13j2zk4f873-web-linden-portal.rork.live")!
    static let backend = URL(string: "https://care-pilot-backend.rork.app")!

    static func portalAPI(origin: URL, path: String) -> URL {
        origin.appending(path: origin.host == portal.host ? "~api/portal/api/\(path)" : "portal/api/\(path)")
    }
}
