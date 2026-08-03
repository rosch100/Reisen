import Foundation
import Security

internal enum KeychainCredentialAccounts {
    static func list(
        keychain: KeychainInternetPasswordKeychainAPI,
        serverHost: String
    ) throws -> [KeychainCredentialAccount] {
        let matches = try KeychainInternetPasswordLookup(keychain: keychain)
            .matchingAttributes(configuredHost: serverHost)
        var seen = Set<KeychainCredentialAccount>()
        var result: [KeychainCredentialAccount] = []
        for attrs in matches {
            guard let username = attrs[kSecAttrAccount] as? String,
                  let server = attrs[kSecAttrServer] as? String else {
                continue
            }
            let account = KeychainCredentialAccount(serverHost: server, username: username)
            if seen.insert(account).inserted {
                result.append(account)
            }
        }
        return KeychainCredentialAccountSort.sorted(result)
    }
}
