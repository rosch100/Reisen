import Foundation
import Security

internal enum KeychainInternetPasswordFallbackLookup {
    static func matchingAttributes(
        keychain: KeychainInternetPasswordKeychainAPI,
        configuredHost: String
    ) throws -> [[CFString: Any]] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true,
            kSecReturnData: false,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ]

        let (status, item) = keychain.itemCopyMatching(query: query as CFDictionary)
        guard status == errSecSuccess else { return [] }
        guard let results = item as? [[CFString: Any]] else {
            throw KeychainCredentialStore.CredentialStoreError.unsupportedItem
        }

        return results.filter { attrs in
            guard let server = attrs[kSecAttrServer] as? String else { return false }
            return KeychainHostMatching.server(server, matches: configuredHost)
        }
    }
}
