import Foundation

internal enum KeychainCredentialNormalize {
    static func normalize(
        credentials: ProviderCredentials,
        serverHost: String
    ) throws -> KeychainCredentialSave.NormalizedInputs {
        let username = credentials.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = credentials.password
        let server = serverHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !username.isEmpty else {
            throw KeychainCredentialStore.CredentialStoreError.emptyUsername
        }
        guard !password.isEmpty else {
            throw KeychainCredentialStore.CredentialStoreError.emptyPassword
        }
        guard !server.isEmpty else {
            throw KeychainCredentialStore.CredentialStoreError.noEntry(serverHost: serverHost)
        }
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainCredentialStore.CredentialStoreError.unsupportedItem
        }

        return KeychainCredentialSave.NormalizedInputs(
            username: username,
            passwordData: passwordData,
            server: server
        )
    }
}
