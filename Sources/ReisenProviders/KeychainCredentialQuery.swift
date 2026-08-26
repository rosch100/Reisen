import Foundation
import Security

/// SSOT für Reisen-eigene Credential-Queries (Data-Protection-Keychain).
///
/// Safari-/iCloud-Internetpasswörter (`kSecClassInternetPassword` + `kSecAttrSynchronizableAny`)
/// lösen den Login-Schlüsselbund-Dialog aus; „Immer erlauben“ hält dort nicht.
enum KeychainCredentialQuery {
    static let service = "de.roschmac.Reisen.provider-credential"

    static func genericBase(account: String? = nil) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecUseDataProtectionKeychain: true,
        ]
        if let account {
            query[kSecAttrAccount] = account
        }
        return query
    }

    static func genericLookupAll() -> [CFString: Any] {
        var query = genericBase()
        query[kSecMatchLimit] = kSecMatchLimitAll
        query[kSecReturnAttributes] = true
        query[kSecReturnData] = false
        query[kSecUseAuthenticationUI] = kSecUseAuthenticationUISkip
        return query
    }

    static func genericSecret(accountID: String) -> [CFString: Any] {
        var query = genericBase(account: accountID)
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnData] = true
        query[kSecUseAuthenticationUI] = kSecUseAuthenticationUISkip
        return query
    }

    static func genericAdd(
        accountID: String,
        passwordData: Data,
        server: String,
        username: String
    ) -> [CFString: Any] {
        var add = genericBase(account: accountID)
        add[kSecValueData] = passwordData
        add[kSecAttrLabel] = "Reisen: \(server) (\(username))"
        add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return add
    }

    static func genericUpdateData(_ passwordData: Data) -> [CFString: Any] {
        [kSecValueData: passwordData]
    }
}
