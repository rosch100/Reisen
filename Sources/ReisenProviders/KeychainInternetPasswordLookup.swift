import Foundation
import Security

/// SSOT: Internetpasswort-Attribute für Host-Kandidaten laden.
internal struct KeychainInternetPasswordLookup: Sendable {
    let keychain: KeychainInternetPasswordKeychainAPI

    func matchingAttributes(configuredHost: String) throws -> [[CFString: Any]] {
        let candidates = KeychainHostMatching.candidates(for: configuredHost)
        guard !candidates.isEmpty else { return [] }

        let directMatches = KeychainInternetPasswordDirectLookup.matchingAttributes(
            keychain: keychain,
            candidates: candidates
        )
        if !directMatches.isEmpty { return directMatches }

        return try KeychainInternetPasswordFallbackLookup.matchingAttributes(
            keychain: keychain,
            configuredHost: configuredHost
        )
    }
}
