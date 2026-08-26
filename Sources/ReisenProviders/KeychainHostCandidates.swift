import Foundation

public enum KeychainHostCandidates {
    /// Geordnete Lookup-Kandidaten: konfigurierter Host zuerst, dann Parent-Domains.
    public static func candidates(for configuredHost: String) -> [String] {
        let lower = configuredHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return [] }
        return KeychainHostParentWalk.walk(from: lower)
    }
}
