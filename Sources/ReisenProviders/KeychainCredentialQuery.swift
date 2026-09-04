import Foundation
import Security

/// SSOT für Reisen-eigene Credential-Queries (Data-Protection-Keychain).
///
/// Safari-/iCloud-Internetpasswörter (`kSecClassInternetPassword` + `kSecAttrSynchronizableAny`)
/// lösen den Login-Schlüsselbund-Dialog aus; „Immer erlauben“ hält dort nicht.
/// App-GenericPasswords nutzen `kSecAttrSynchronizable=true` (iCloud-Keychain), nicht Safari-Einträge.
enum KeychainCredentialQuery {
    static let service = "de.roschmac.Reisen.provider-credential"

    static func genericBase(account: String? = nil, synchronizable: Bool = true) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecUseDataProtectionKeychain: true,
            kSecAttrSynchronizable: synchronizable,
        ]
        if let account {
            query[kSecAttrAccount] = account
        }
        return query
    }

    /// Legacy device-only Items (vor Sync-Migration).
    static func genericLocalOnlyBase(account: String? = nil) -> [CFString: Any] {
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

    static func genericLookupAll(synchronizable: Bool = true) -> [CFString: Any] {
        var query = genericBase(synchronizable: synchronizable)
        query[kSecMatchLimit] = kSecMatchLimitAll
        query[kSecReturnAttributes] = true
        query[kSecReturnData] = false
        query[kSecUseAuthenticationUI] = kSecUseAuthenticationUISkip
        return query
    }

    static func genericLookupAllLocalOnly() -> [CFString: Any] {
        var query = genericLocalOnlyBase()
        query[kSecMatchLimit] = kSecMatchLimitAll
        query[kSecReturnAttributes] = true
        query[kSecReturnData] = false
        query[kSecUseAuthenticationUI] = kSecUseAuthenticationUISkip
        return query
    }

    static func genericSecret(accountID: String, synchronizable: Bool = true) -> [CFString: Any] {
        var query = genericBase(account: accountID, synchronizable: synchronizable)
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnData] = true
        query[kSecUseAuthenticationUI] = kSecUseAuthenticationUISkip
        return query
    }

    static func genericSecretLocalOnly(accountID: String) -> [CFString: Any] {
        var query = genericLocalOnlyBase(account: accountID)
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
        var add = genericBase(account: accountID, synchronizable: true)
        add[kSecValueData] = passwordData
        add[kSecAttrLabel] = "Reisen: \(server) (\(username))"
        add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        return add
    }

    static func genericUpdateData(_ passwordData: Data) -> [CFString: Any] {
        [kSecValueData: passwordData]
    }
}
