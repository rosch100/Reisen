import Foundation

/// Host-Matching für Provider-Keychain-Accounts (Subdomain ↔ Apex).
public enum KeychainHostMatching {
    public static func candidates(for configuredHost: String) -> [String] {
        KeychainHostCandidates.candidates(for: configuredHost)
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
