import Foundation
import Security

/// SSOT: App-eigene Generic-Passwords (kein Login-Schlüsselbund / keine Safari-Items).
internal struct KeychainInternetPasswordLookup: Sendable {
    let keychain: KeychainInternetPasswordKeychainAPI

    func matchingAttributes(configuredHost: String) throws -> [[CFString: Any]] {
        let candidates = KeychainHostMatching.candidates(for: configuredHost)
        guard !candidates.isEmpty else { return [] }
        return try KeychainGenericPasswordLookup.matchingAttributes(
            keychain: keychain,
            configuredHost: configuredHost
        )
    }
}
