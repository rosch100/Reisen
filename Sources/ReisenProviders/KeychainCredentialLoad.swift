import Foundation
import Security

internal enum KeychainCredentialLoad {
    static func credentials(
        keychain: KeychainInternetPasswordKeychainAPI,
        for account: KeychainCredentialAccount
    ) throws -> ProviderCredentials {
        let query = KeychainCredentialQuery.genericSecret(accountID: account.id)
        let (status, secretItem) = keychain.itemCopyMatching(query: query as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainCredentialStore.CredentialStoreError.noEntry(serverHost: account.serverHost)
        }
        guard let passwordData = secretItem as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            throw KeychainCredentialStore.CredentialStoreError.unsupportedItem
        }
        return ProviderCredentials(username: account.username, password: password)
    }
}
