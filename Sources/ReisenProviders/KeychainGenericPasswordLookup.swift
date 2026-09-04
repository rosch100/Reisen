import Foundation
import Security

internal enum KeychainGenericPasswordLookup {
    static func matchingAttributes(
        keychain: KeychainInternetPasswordKeychainAPI,
        configuredHost: String
    ) throws -> [[CFString: Any]] {
        let (status, item) = keychain.itemCopyMatching(
            query: KeychainCredentialQuery.genericLookupAll() as CFDictionary
        )
        if status == errSecItemNotFound || status == errSecInteractionNotAllowed {
            return []
        }
        guard status == errSecSuccess else { return [] }
        guard let results = item as? [[CFString: Any]] else {
            throw KeychainCredentialStore.CredentialStoreError.unsupportedItem
        }

        return results.compactMap { attrs in
            normalizedAttributes(attrs, matching: configuredHost)
        }
    }

    /// Auch lokale (noch nicht migrierte) Items für denselben Host.
    /// Synchronizable Matches gewinnen bei gleichem normalisiertem Account.
    static func matchingAttributesIncludingLocalOnly(
        keychain: KeychainInternetPasswordKeychainAPI,
        configuredHost: String
    ) throws -> [[CFString: Any]] {
        var byAccount: [String: [CFString: Any]] = [:]
        for attrs in try matchingAttributes(keychain: keychain, configuredHost: configuredHost) {
            guard let account = attrs[kSecAttrAccount] as? String else { continue }
            byAccount[account] = attrs
        }
        let (status, item) = keychain.itemCopyMatching(
            query: KeychainCredentialQuery.genericLookupAllLocalOnly() as CFDictionary
        )
        if status == errSecSuccess, let results = item as? [[CFString: Any]] {
            for attrs in results.compactMap({ normalizedAttributes($0, matching: configuredHost) }) {
                guard let account = attrs[kSecAttrAccount] as? String else { continue }
                if byAccount[account] == nil {
                    byAccount[account] = attrs
                }
            }
        }
        return Array(byAccount.values)
    }

    private static func normalizedAttributes(
        _ attrs: [CFString: Any],
        matching configuredHost: String
    ) -> [CFString: Any]? {
        guard let accountKey = attrs[kSecAttrAccount] as? String,
              let parsed = KeychainCredentialAccount.parseID(accountKey),
              KeychainHostMatching.server(parsed.serverHost, matches: configuredHost)
        else {
            return nil
        }
        var normalized = attrs
        normalized[kSecAttrServer] = parsed.serverHost
        normalized[kSecAttrAccount] = parsed.username
        return normalized
    }
}
