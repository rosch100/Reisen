import Foundation
import Security

internal enum KeychainCredentialUpsert {
    static func upsert(
        keychain: KeychainInternetPasswordKeychainAPI,
        normalized: KeychainCredentialSave.NormalizedInputs
    ) throws {
        let existingQuery: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: normalized.server,
            kSecAttrAccount: normalized.username,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ]
        let update: [CFString: Any] = [
            kSecValueData: normalized.passwordData,
            kSecAttrProtocol: kSecAttrProtocolHTTPS
        ]

        let updateStatus = keychain.itemUpdate(
            existingQuery: existingQuery as CFDictionary,
            update: update as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound {
            throw KeychainCredentialStore.CredentialStoreError.saveFailed(status: updateStatus)
        }

        let add: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: normalized.server,
            kSecAttrAccount: normalized.username,
            kSecAttrProtocol: kSecAttrProtocolHTTPS,
            kSecValueData: normalized.passwordData,
            kSecAttrLabel: "\(normalized.server) (\(normalized.username))"
        ]
        let addStatus = keychain.itemAdd(add: add as CFDictionary)
        guard addStatus == errSecSuccess else {
            throw KeychainCredentialStore.CredentialStoreError.saveFailed(status: addStatus)
        }
    }
}
