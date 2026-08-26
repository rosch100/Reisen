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
