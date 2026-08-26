import Foundation
import Security

/// Speichern/Normalisieren von Provider-Credentials (SSOT).
internal enum KeychainCredentialSave {
    struct NormalizedInputs {
        let username: String
        let passwordData: Data
        let server: String
    }

    static func normalize(
        credentials: ProviderCredentials,
        serverHost: String
    ) throws -> NormalizedInputs {
        try KeychainCredentialNormalize.normalize(credentials: credentials, serverHost: serverHost)
    }

    static func upsert(
        keychain: KeychainInternetPasswordKeychainAPI,
        credentials: ProviderCredentials,
        serverHost: String
    ) throws {
        let normalized = try normalize(credentials: credentials, serverHost: serverHost)
        try KeychainCredentialUpsert.upsert(keychain: keychain, normalized: normalized)
    }
}
