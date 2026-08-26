import Foundation
import Security

/// Read-only/write store for provider credentials.
///
/// Liest und schreibt Internetpasswörter (`kSecClassInternetPassword`).
/// Einträge nur in der Passwords-App sind für Drittanbieter-Apps nicht lesbar
/// (Apple Access-Group-Schutz) — deshalb können Konten hier manuell gespeichert werden
/// (z. B. nach Kopieren aus Passwords).
public final class KeychainCredentialStore {
    private let keychain: KeychainInternetPasswordKeychainAPI

    public init() {
        self.keychain = SecurityInternetPasswordKeychainAPI()
    }

    internal init(keychain: KeychainInternetPasswordKeychainAPI) {
        self.keychain = keychain
    }

    /// Alle lesbaren Internetpasswort-Accounts für den konfigurierten Host (inkl. Subdomains).
    public func accounts(serverHost: String) throws -> [KeychainCredentialAccount] {
        try KeychainCredentialAccounts.list(keychain: keychain, serverHost: serverHost)
    }

    /// Lädt Secret für einen konkreten Account.
    public func credentials(for account: KeychainCredentialAccount) throws -> ProviderCredentials {
        try KeychainCredentialLoad.credentials(keychain: keychain, for: account)
    }

    /// Speichert/aktualisiert ein Internetpasswort für den Provider-Host (lesbar für diese App).
    public func save(credentials: ProviderCredentials, serverHost: String) throws {
        try KeychainCredentialSave.upsert(
            keychain: keychain,
            credentials: credentials,
            serverHost: serverHost
        )
    }
}
