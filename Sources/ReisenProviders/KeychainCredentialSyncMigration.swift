import Foundation
import Security
import ReisenDiagnostics
import ReisenDomain

/// Migriert device-only App-Credentials zu iCloud-Keychain-synchronizable Items.
public enum KeychainCredentialSyncMigration: Sendable {
    /// - Returns: Anzahl migrierter Konten.
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

    private static func deleteLocalOnlySucceeded(
        keychain: KeychainInternetPasswordKeychainAPI,
        accountKey: String
    ) -> Bool {
        let deleteQuery = KeychainCredentialQuery.genericLocalOnlyBase(account: accountKey)
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
}
