import Foundation

/// Host-Matching für Keychain-Internetpasswörter (Subdomain ↔ Apex).
public enum KeychainHostMatching {
    /// Geordnete Lookup-Kandidaten: konfigurierter Host zuerst, dann Parent-Domains.
    public static func candidates(for configuredHost: String) -> [String] {
        let lower = configuredHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return [] }

        var result: [String] = []
        var current = lower
        while true {
            if !result.contains(current) {
                result.append(current)
            }
            let parts = current.split(separator: ".").map(String.init)
            guard parts.count > 2 else { break }
            current = parts.dropFirst().joined(separator: ".")
        }
        return result
    }

    /// `true`, wenn `server` dem konfigurierten Host entspricht oder eine Subdomain davon ist.
    public static func server(_ server: String, matches configuredHost: String) -> Bool {
        let serverHost = server.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let configured = configuredHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !serverHost.isEmpty, !configured.isEmpty else { return false }
        if serverHost == configured { return true }
        return serverHost.hasSuffix("." + configured)
    }
}
