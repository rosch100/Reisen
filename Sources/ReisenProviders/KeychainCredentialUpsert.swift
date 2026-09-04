import Foundation
import Security

internal enum KeychainCredentialUpsert {
    static func upsert(
        keychain: KeychainInternetPasswordKeychainAPI,
        normalized: KeychainCredentialSave.NormalizedInputs
    ) throws {
        let accountID = KeychainCredentialAccount.makeID(
            serverHost: normalized.server,
            username: normalized.username
        )
        let existingQuery = KeychainCredentialQuery.genericBase(account: accountID, synchronizable: true)
        let update = KeychainCredentialQuery.genericUpdateData(normalized.passwordData)

        let updateStatus = keychain.itemUpdate(
            existingQuery: existingQuery as CFDictionary,
            update: update as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound {
            throw KeychainCredentialStore.CredentialStoreError.saveFailed(status: updateStatus)
        }

        let add = KeychainCredentialQuery.genericAdd(
            accountID: accountID,
            passwordData: normalized.passwordData,
            server: normalized.server,
            username: normalized.username
        )
        let addStatus = keychain.itemAdd(add: add as CFDictionary)
        guard addStatus == errSecSuccess else {
            throw KeychainCredentialStore.CredentialStoreError.saveFailed(status: addStatus)
        }
    }
}
