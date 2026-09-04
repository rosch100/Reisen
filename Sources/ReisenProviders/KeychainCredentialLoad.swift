import Foundation
import Security

internal enum KeychainCredentialLoad {
    static func credentials(
        keychain: KeychainInternetPasswordKeychainAPI,
        for account: KeychainCredentialAccount
    ) throws -> ProviderCredentials {
        let query = KeychainCredentialQuery.genericSecret(accountID: account.id)
        let (status, secretItem) = keychain.itemCopyMatching(query: query as CFDictionary)
        if status == errSecSuccess {
            guard let passwordData = secretItem as? Data,
                  let password = String(data: passwordData, encoding: .utf8) else {
                throw KeychainCredentialStore.CredentialStoreError.unsupportedItem
            }
            return ProviderCredentials(username: account.username, password: password)
        }

        let localQuery = KeychainCredentialQuery.genericSecretLocalOnly(accountID: account.id)
        let (localStatus, localItem) = keychain.itemCopyMatching(query: localQuery as CFDictionary)
        guard localStatus == errSecSuccess else {
            throw KeychainCredentialStore.CredentialStoreError.noEntry(serverHost: account.serverHost)
        }
        guard let passwordData = localItem as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            throw KeychainCredentialStore.CredentialStoreError.unsupportedItem
        }
        return ProviderCredentials(username: account.username, password: password)
    }
}
