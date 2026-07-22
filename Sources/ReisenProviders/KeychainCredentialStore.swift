import Foundation
import Security

internal protocol KeychainInternetPasswordKeychainAPI: Sendable {
    func itemCopyMatching(query: CFDictionary) -> (status: OSStatus, item: CFTypeRef?)
    func itemUpdate(existingQuery: CFDictionary, update: CFDictionary) -> OSStatus
    func itemAdd(add: CFDictionary) -> OSStatus
}

internal struct SecurityInternetPasswordKeychainAPI: KeychainInternetPasswordKeychainAPI {
    func itemCopyMatching(query: CFDictionary) -> (status: OSStatus, item: CFTypeRef?) {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query, &item)
        return (status: status, item: item)
    }

    func itemUpdate(existingQuery: CFDictionary, update: CFDictionary) -> OSStatus {
        SecItemUpdate(existingQuery, update)
    }

    func itemAdd(add: CFDictionary) -> OSStatus {
        SecItemAdd(add, nil)
    }
}

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

    public enum CredentialStoreError: LocalizedError, Equatable {
        case noEntry(serverHost: String)
        case unsupportedItem
        case unexpectedItemAttributes
        case saveFailed(status: OSStatus)
        case emptyUsername
        case emptyPassword

        public var errorDescription: String? {
            switch self {
            case .noEntry(let serverHost):
                return """
                Kein lesbares Konto für '\(serverHost)'.
                Passwords-App-Einträge sind für andere Apps gesperrt.
                Primärweg: „Konto speichern…“ — E-Mail und Kennwort aus Passwords hier hinterlegen.
                (Optional: Internetpasswort in der Schlüsselbundverwaltung für '\(serverHost)' anlegen.)
                """
            case .unsupportedItem:
                return "Keychain-Eintrag hat ein unerwartetes Format."
            case .unexpectedItemAttributes:
                return "Keychain-Eintrag fehlen notwendige Attribute."
            case .saveFailed(let status):
                return "Keychain-Speichern fehlgeschlagen (Status \(status))."
            case .emptyUsername:
                return "Benutzername/E-Mail darf nicht leer sein."
            case .emptyPassword:
                return "Kennwort darf nicht leer sein."
            }
        }
    }

    /// Alle lesbaren Internetpasswort-Accounts für den konfigurierten Host (inkl. Subdomains).
    public func accounts(serverHost: String) throws -> [KeychainCredentialAccount] {
        let matches = try matchingInternetPasswordAttributes(configuredHost: serverHost)
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
        return result.sorted {
            if $0.username != $1.username {
                return $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending
            }
            return $0.serverHost.localizedCaseInsensitiveCompare($1.serverHost) == .orderedAscending
        }
    }

    /// Lädt Secret für einen konkreten Account.
    public func credentials(for account: KeychainCredentialAccount) throws -> ProviderCredentials {
        try credentials(server: account.serverHost, username: account.username)
    }

    /// Speichert/aktualisiert ein Internetpasswort für den Provider-Host (lesbar für diese App).
    public func save(credentials: ProviderCredentials, serverHost: String) throws {
        let normalized = try normalizedSaveInputs(credentials: credentials, serverHost: serverHost)

        let username = normalized.username
        let passwordData = normalized.passwordData
        let server = normalized.server

        let existingQuery: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: server,
            kSecAttrAccount: username,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ]

        let update: [CFString: Any] = [
            kSecValueData: passwordData,
            kSecAttrProtocol: kSecAttrProtocolHTTPS
        ]

        let updateStatus = keychain.itemUpdate(
            existingQuery: existingQuery as CFDictionary,
            update: update as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            throw CredentialStoreError.saveFailed(status: updateStatus)
        }

        let add: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: server,
            kSecAttrAccount: username,
            kSecAttrProtocol: kSecAttrProtocolHTTPS,
            kSecValueData: passwordData,
            kSecAttrLabel: "\(server) (\(username))"
        ]

        let addStatus = keychain.itemAdd(add: add as CFDictionary)
        guard addStatus == errSecSuccess else {
            throw CredentialStoreError.saveFailed(status: addStatus)
        }
    }

    private func credentials(server: String, username: String) throws -> ProviderCredentials {
        let secretQuery: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecAttrServer: server,
            kSecAttrAccount: username,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ]

        let (status, secretItem) = keychain.itemCopyMatching(query: secretQuery as CFDictionary)
        guard status == errSecSuccess else {
            throw CredentialStoreError.noEntry(serverHost: server)
        }
        guard let passwordData = secretItem as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            throw CredentialStoreError.unsupportedItem
        }

        return ProviderCredentials(username: username, password: password)
    }

    private struct NormalizedSaveInputs {
        let username: String
        let passwordData: Data
        let server: String
    }

    private func normalizedSaveInputs(
        credentials: ProviderCredentials,
        serverHost: String
    ) throws -> NormalizedSaveInputs {
        let username = credentials.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = credentials.password
        let server = serverHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !username.isEmpty else { throw CredentialStoreError.emptyUsername }
        guard !password.isEmpty else { throw CredentialStoreError.emptyPassword }
        guard !server.isEmpty else { throw CredentialStoreError.noEntry(serverHost: serverHost) }

        guard let passwordData = password.data(using: .utf8) else {
            throw CredentialStoreError.unsupportedItem
        }

        return NormalizedSaveInputs(username: username, passwordData: passwordData, server: server)
    }

    private func matchingInternetPasswordAttributes(configuredHost: String) throws -> [[CFString: Any]] {
        let candidates = KeychainHostMatching.candidates(for: configuredHost)
        guard !candidates.isEmpty else { return [] }

        let directMatches = matchingInternetPasswordAttributesDirect(candidates: candidates)
        if !directMatches.isEmpty { return directMatches }

        return try matchingInternetPasswordAttributesFallbackFullScan(configuredHost: configuredHost)
    }

    private func matchingInternetPasswordAttributesDirect(
        candidates: [String]
    ) -> [[CFString: Any]] {
        // 1) Direkte Server-Treffer pro Kandidat.
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

            for attrs in results {
                guard let username = attrs[kSecAttrAccount] as? String,
                      let server = attrs[kSecAttrServer] as? String else { continue }
                let key = "\(server)\u{1f}\(username)"
                if seenKeys.insert(key).inserted {
                    collected.append(attrs)
                }
            }
        }

        return collected
    }

    private func matchingInternetPasswordAttributesFallbackFullScan(
        configuredHost: String
    ) throws -> [[CFString: Any]] {
        // 2) Fallback: Full-Scan, Subdomains matchen (booking.com → secure.booking.com).
        let query: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true,
            kSecReturnData: false,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ]

        let (status, item) = keychain.itemCopyMatching(query: query as CFDictionary)
        guard status == errSecSuccess else { return [] }
        guard let results = item as? [[CFString: Any]] else {
            throw CredentialStoreError.unsupportedItem
        }

        return results.filter { attrs in
            guard let server = attrs[kSecAttrServer] as? String else { return false }
            return KeychainHostMatching.server(server, matches: configuredHost)
        }
    }
}
