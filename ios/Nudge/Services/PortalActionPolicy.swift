import Foundation

/// Defense in depth: submission controls require approval even if a model omits the flag.
nonisolated enum PortalActionPolicy {
    static func needsApproval(element: Element?, args: [String: JSONValue]) -> Bool {
        if args["consequential"]?.boolValue == true { return true }
        guard let element else { return true }
        if element.type == "submit" { return true }
        let pattern = #"(?i)(schedule|book|confirm|cancel appointment|submit|\bsend\b|request refill|finish check|\bsign\b(?! in)|sign out|log out)"#
        return element.name.range(of: pattern, options: .regularExpression) != nil
    }
}
