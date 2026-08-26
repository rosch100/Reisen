import Foundation
import Security

internal enum KeychainInternetPasswordDirectLookup {
    static func matchingAttributes(
        keychain: KeychainInternetPasswordKeychainAPI,
        candidates: [String]
    ) -> [[CFString: Any]] {
        var collected: [[CFString: Any]] = []
        var seenKeys = Set<String>()

        for host in candidates {
            let query: [CFString: Any] = [
                kSecClass: kSecClassInternetPassword,
                kSecAttrServer: host,
                kSecMatchLimit: kSecMatchLimitAll,
                kSecReturnAttributes: true,
                kSecReturnData: false,
                kSecAttrSynchronizable: kSecAttrSynchronizableAny
            ]

            let (status, item) = keychain.itemCopyMatching(query: query as CFDictionary)
            guard status == errSecSuccess,
                  let results = item as? [[CFString: Any]] else { continue }

            KeychainInternetPasswordResultMerge.appendUnique(
                results: results,
                into: &collected,
                seenKeys: &seenKeys
            )
        }

        return collected
    }
}
