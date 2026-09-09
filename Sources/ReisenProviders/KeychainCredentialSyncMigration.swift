import Foundation
import Security
import ReisenDiagnostics
import ReisenDomain

/// Migriert device-only App-Credentials zu iCloud-Keychain-synchronizable Items
/// und Default-Access-Group-Items in die shared Group (macOS↔iOS).
public enum KeychainCredentialSyncMigration: Sendable {
    /// - Returns: Anzahl migrierter Konten (local-only + Access-Group).
    @discardableResult
    public static func migrateLocalOnlyToSynchronizable(
        store: KeychainCredentialStore = KeychainCredentialStore()
    ) -> Int {
        store.migrateLocalOnlyToSynchronizable()
    }
}

enum KeychainCredentialSyncMigrationRunner {
    static func run(
        keychain: KeychainInternetPasswordKeychainAPI,
        save: (ProviderCredentials, String) throws -> Void
    ) -> Int {
        let localMigrated = migrateLocalOnly(keychain: keychain, save: save)
        let accessMigrated = migrateDefaultAccessGroupToShared(keychain: keychain, save: save)
        return localMigrated + accessMigrated
    }

    private static func migrateLocalOnly(
        keychain: KeychainInternetPasswordKeychainAPI,
        save: (ProviderCredentials, String) throws -> Void
    ) -> Int {
        let query = KeychainCredentialQuery.genericLookupAllLocalOnly()
        let (status, item) = keychain.itemCopyMatching(query: query as CFDictionary)
        guard status == errSecSuccess, let results = item as? [[CFString: Any]] else {
            if status != errSecItemNotFound && status != errSecInteractionNotAllowed {
                recordMigration(result: .failed, reason: "lookup_failed")
            }
            return 0
        }

        var migrated = 0
        for attrs in results {
            guard let accountKey = attrs[kSecAttrAccount] as? String,
                  let parsed = KeychainCredentialAccount.parseID(accountKey)
            else { continue }

            let secretQuery = KeychainCredentialQuery.genericSecretLocalOnly(accountID: accountKey)
            let (secretStatus, secretItem) = keychain.itemCopyMatching(query: secretQuery as CFDictionary)
            guard secretStatus == errSecSuccess,
                  let passwordData = secretItem as? Data,
                  let password = String(data: passwordData, encoding: .utf8)
            else { continue }

            let syncQuery = KeychainCredentialQuery.genericSecret(accountID: accountKey, synchronizable: true)
            let (syncStatus, _) = keychain.itemCopyMatching(query: syncQuery as CFDictionary)
            if syncStatus == errSecSuccess {
                // Synchronizable existiert bereits — lokales Duplikat nur aufräumen, nicht überschreiben.
                if deleteLocalOnlySucceeded(keychain: keychain, accountKey: accountKey) {
                    migrated += 1
                }
                continue
            }

            do {
                try save(
                    ProviderCredentials(username: parsed.username, password: password),
                    parsed.serverHost
                )
                if deleteLocalOnlySucceeded(keychain: keychain, accountKey: accountKey) {
                    migrated += 1
                }
            } catch {
                recordMigration(result: .failed, reason: "item_save_failed")
                continue
            }
        }

        recordMigration(
            result: .succeeded,
            reason: migrated == 0 ? "none" : "migrated_count_\(migrated)"
        )
        return migrated
    }

    /// Items, die vor Keychain-Sharing in der Default-Access-Group lagen, in die shared Group heben.
    private static func migrateDefaultAccessGroupToShared(
        keychain: KeychainInternetPasswordKeychainAPI,
        save: (ProviderCredentials, String) throws -> Void
    ) -> Int {
        let query = KeychainCredentialQuery.genericLookupAllSynchronizableAnyAccessGroup()
        let (status, item) = keychain.itemCopyMatching(query: query as CFDictionary)
        guard status == errSecSuccess, let results = item as? [[CFString: Any]] else {
            if status != errSecItemNotFound && status != errSecInteractionNotAllowed {
                recordAccessGroupMigration(result: .failed, reason: "lookup_failed")
            }
            return 0
        }

        var migrated = 0
        for attrs in results {
            guard let accountKey = attrs[kSecAttrAccount] as? String,
                  let parsed = KeychainCredentialAccount.parseID(accountKey)
            else { continue }

            guard let oldAccessGroup = attrs[kSecAttrAccessGroup] as? String else {
                recordAccessGroupMigration(result: .skipped, reason: "missing_access_group_attr")
                continue
            }
            if oldAccessGroup == KeychainCredentialAccessGroup.value {
                continue
            }

            let secretQuery = KeychainCredentialQuery.genericSecretSynchronizableAnyAccessGroup(
                accountID: accountKey
            )
            let (secretStatus, secretItem) = keychain.itemCopyMatching(query: secretQuery as CFDictionary)
            guard secretStatus == errSecSuccess,
                  let passwordData = secretItem as? Data,
                  let password = String(data: passwordData, encoding: .utf8)
            else { continue }

            let sharedQuery = KeychainCredentialQuery.genericSecret(accountID: accountKey)
            let (sharedStatus, _) = keychain.itemCopyMatching(query: sharedQuery as CFDictionary)

            if sharedStatus == errSecSuccess {
                if deleteSynchronizable(
                    keychain: keychain,
                    accountKey: accountKey,
                    accessGroup: oldAccessGroup
                ) {
                    migrated += 1
                }
                continue
            }

            do {
                try save(
                    ProviderCredentials(username: parsed.username, password: password),
                    parsed.serverHost
                )
                if deleteSynchronizable(
                    keychain: keychain,
                    accountKey: accountKey,
                    accessGroup: oldAccessGroup
                ) {
                    migrated += 1
                }
            } catch {
                recordAccessGroupMigration(result: .failed, reason: "item_save_failed")
                continue
            }
        }

        recordAccessGroupMigration(
            result: .succeeded,
            reason: migrated == 0 ? "none" : "migrated_count_\(migrated)"
        )
        return migrated
    }

    private static func deleteLocalOnlySucceeded(
        keychain: KeychainInternetPasswordKeychainAPI,
        accountKey: String
    ) -> Bool {
        let deleteQuery = KeychainCredentialQuery.genericLocalOnlyBase(account: accountKey)
        let deleteStatus = keychain.itemDelete(query: deleteQuery as CFDictionary)
        return deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound
    }

    private static func deleteSynchronizable(
        keychain: KeychainInternetPasswordKeychainAPI,
        accountKey: String,
        accessGroup: String
    ) -> Bool {
        var deleteQuery = KeychainCredentialQuery.genericBase(
            account: accountKey,
            synchronizable: true,
            sharedAccessGroup: false
        )
        deleteQuery[kSecAttrAccessGroup] = accessGroup
        let deleteStatus = keychain.itemDelete(query: deleteQuery as CFDictionary)
        return deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound
    }

    private static func recordMigration(result: DiagnosticResult, reason: String) {
        let event = DiagnosticEvent(
            context: DiagnosticContext(
                runID: UUID(),
                providerID: .manual,
                operation: "keychain_credential_sync_migration"
            ),
            component: "KeychainCredentialStore",
            phase: "migrate",
            event: "keychain_credential_migrate",
            result: result,
            reason: reason
        )
        Task {
            await DiagnosticLogger.shared.record(event)
        }
    }

    private static func recordAccessGroupMigration(result: DiagnosticResult, reason: String) {
        let event = DiagnosticEvent(
            context: DiagnosticContext(
                runID: UUID(),
                providerID: .manual,
                operation: "keychain_credential_access_group_migration"
            ),
            component: "KeychainCredentialStore",
            phase: "migrate",
            event: "keychain_credential_access_group_migrate",
            result: result,
            reason: reason
        )
        Task {
            await DiagnosticLogger.shared.record(event)
        }
    }
}
