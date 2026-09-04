import Foundation
import Security

/// Read-only/write store for provider credentials.
///
/// Speichert app-eigene Generic Passwords in der Data-Protection-Keychain
/// (kein Login-Schlüsselbund-Dialog). Passwords-App-Einträge sind für Drittanbieter
/// nicht lesbar — Konten deshalb hier manuell speichern (z. B. nach Kopieren aus Passwords).
public final class KeychainCredentialStore {
    private let keychain: KeychainInternetPasswordKeychainAPI

    public init() {
        self.keychain = SecurityInternetPasswordKeychainAPI()
    }

    internal init(keychain: KeychainInternetPasswordKeychainAPI) {
        self.keychain = keychain
    }

    /// Lesbare Accounts für den konfigurierten Host (nur app-eigene Generic Passwords).
    public func accounts(serverHost: String) throws -> [KeychainCredentialAccount] {
        try KeychainCredentialAccounts.list(keychain: keychain, serverHost: serverHost)
    }

    /// Lädt Secret für einen konkreten Account.
    public func credentials(for account: KeychainCredentialAccount) throws -> ProviderCredentials {
        try KeychainCredentialLoad.credentials(keychain: keychain, for: account)
    }

    /// Speichert/aktualisiert das app-eigene Generic Password für den Provider-Host.
    public func save(credentials: ProviderCredentials, serverHost: String) throws {
        try KeychainCredentialSave.upsert(
            keychain: keychain,
            credentials: credentials,
            serverHost: serverHost
        )
    }

    /// Migriert lokale ThisDeviceOnly-Items zu synchronizable (iCloud-Keychain).
    @discardableResult
    public func migrateLocalOnlyToSynchronizable() -> Int {
        KeychainCredentialSyncMigrationRunner.run(keychain: keychain, save: save)
    }
}

