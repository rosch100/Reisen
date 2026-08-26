import Testing
import Foundation
import Security
@testable import ReisenProviders

final class FakeKeychainInternetPasswordAPI: KeychainInternetPasswordKeychainAPI {
    var copyMatchingCallCount: Int = 0
    private(set) var copyMatchingQueries: [[CFString: Any]] = []

    var genericAttributeResults: Any = [[CFString: Any]]()
    var genericCopyStatus: OSStatus = errSecSuccess
    var genericSecretByAccount: [String: Data] = [:]

    var updateCalls: Int = 0
    var addCalls: Int = 0

    var updateStatus: OSStatus = errSecSuccess
    var addStatus: OSStatus = errSecSuccess

    private(set) var lastUpdateExistingQuery: CFDictionary?
    private(set) var lastAddQuery: CFDictionary?

    func itemCopyMatching(query: CFDictionary) -> (status: OSStatus, item: CFTypeRef?) {
        copyMatchingCallCount += 1
        let dict = (query as? [CFString: Any]) ?? [:]
        copyMatchingQueries.append(dict)

        let wantsData = dict[kSecReturnData] as? Bool == true

        if keychainQueryIsGenericPassword(dict) {
            if wantsData {
                let account = dict[kSecAttrAccount] as? String ?? ""
                if let data = genericSecretByAccount[account] {
                    return (errSecSuccess, data as CFTypeRef)
                }
                return (errSecItemNotFound, nil)
            }
            if let typed = genericAttributeResults as? [[CFString: Any]] {
                return (genericCopyStatus, typed as CFTypeRef)
            }
            return (genericCopyStatus, genericAttributeResults as AnyObject)
        }

        return (errSecParam, nil)
    }

    func itemUpdate(existingQuery: CFDictionary, update: CFDictionary) -> OSStatus {
        updateCalls += 1
        lastUpdateExistingQuery = existingQuery
        return updateStatus
    }

    func itemAdd(add: CFDictionary) -> OSStatus {
        addCalls += 1
        lastAddQuery = add
        if let dict = add as? [CFString: Any],
           let account = dict[kSecAttrAccount] as? String,
           let data = dict[kSecValueData] as? Data {
            genericSecretByAccount[account] = data
        }
        return addStatus
    }
}

extension FakeKeychainInternetPasswordAPI: @unchecked Sendable {}

private func genericAccountAttributes(server: String, username: String) -> [CFString: Any] {
    [
        kSecAttrService as CFString: KeychainCredentialQuery.service,
        kSecAttrAccount as CFString: KeychainCredentialAccount.makeID(serverHost: server, username: username),
    ]
}

struct KeychainCredentialStoreHotspotsTests {
    @Test("KeychainCredentialStore accounts: leerer Host ergibt leere Liste ohne Keychain-Aufrufe")
    func accounts_emptyConfiguredHost_returnsEmpty_withoutKeychainCalls() throws {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)

        let accounts = try store.accounts(serverHost: "  \n\t")
        #expect(accounts.isEmpty)
        #expect(fake.copyMatchingCallCount == 0)
    }

    @Test("KeychainCredentialStore accounts: direkte Matches werden deduped und sortiert")
    func accounts_directMatches_dedupes_and_sorts() throws {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)

        fake.genericAttributeResults = [
            genericAccountAttributes(server: "booking.com", username: "b@a.de"),
            genericAccountAttributes(server: "booking.com", username: "a@b.de"),
            genericAccountAttributes(server: "booking.com", username: "b@a.de"),
        ]

        let accounts = try store.accounts(serverHost: "booking.com")
        #expect(accounts.count == 2)
        #expect(accounts.map(\.username) == ["a@b.de", "b@a.de"])
    }

    @Test("KeychainCredentialStore accounts: Host-Filter trifft Subdomains ohne Full-Scan")
    func accounts_hostFilter_matchesSubdomainsWithoutFullScan() throws {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)

        fake.genericAttributeResults = [
            genericAccountAttributes(server: "secure.booking.com", username: "user1@x.de"),
            genericAccountAttributes(server: "other.com", username: "ignored@x.de"),
        ]

        let accounts = try store.accounts(serverHost: "booking.com")
        #expect(accounts.count == 1)
        #expect(accounts.first?.serverHost == "secure.booking.com")
        #expect(accounts.first?.username == "user1@x.de")

        let unconstrainedInternetScans = fake.copyMatchingQueries.filter(keychainQueryIsInternetPassword)
        #expect(unconstrainedInternetScans.isEmpty)
    }

    @Test("KeychainCredentialStore save: Update success beendet ohne Add")
    func save_updateSuccess_returnsWithoutAdd() throws {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)

        fake.updateStatus = errSecSuccess
        fake.addStatus = errSecSuccess

        try store.save(
            credentials: ProviderCredentials(username: "  u@x.de  ", password: "pw"),
            serverHost: "  BOOKING.COM "
        )

        #expect(fake.updateCalls == 1)
        #expect(fake.addCalls == 0)
        if let dict = fake.lastUpdateExistingQuery as? [CFString: Any] {
            #expect((dict[kSecAttrAccount] as? String) == "booking.com\u{1f}u@x.de")
            #expect((dict[kSecAttrService] as? String) == KeychainCredentialQuery.service)
            #expect(keychainQueryIsGenericPassword(dict))
        } else {
            #expect(Bool(false))
        }
    }

    @Test("KeychainCredentialStore save: Update not found → Add wird ausgeführt")
    func save_updateNotFound_adds() throws {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)

        fake.updateStatus = errSecItemNotFound
        fake.addStatus = errSecSuccess

        try store.save(
            credentials: ProviderCredentials(username: "u2@x.de", password: "pw"),
            serverHost: "booking.com"
        )

        #expect(fake.updateCalls == 1)
        #expect(fake.addCalls == 1)
        if let dict = fake.lastAddQuery as? [CFString: Any] {
            #expect((dict[kSecAttrAccount] as? String) == "booking.com\u{1f}u2@x.de")
        } else {
            #expect(Bool(false))
        }
    }

    @Test("KeychainCredentialStore save: leeren Username → emptyUsername")
    func save_emptyUsername_throwsEmptyUsername() {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)

        #expect(throws: KeychainCredentialStore.CredentialStoreError.emptyUsername) {
            try store.save(
                credentials: ProviderCredentials(username: "   \n", password: "pw"),
                serverHost: "booking.com"
            )
        }
    }

    @Test("KeychainCredentialStore save: leeres Passwort → emptyPassword")
    func save_emptyPassword_throwsEmptyPassword() {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)

        #expect(throws: KeychainCredentialStore.CredentialStoreError.emptyPassword) {
            try store.save(
                credentials: ProviderCredentials(username: "u@x.de", password: ""),
                serverHost: "booking.com"
            )
        }
    }

    @Test("KeychainCredentialStore save: Update Fehler (kein notFound) → saveFailed")
    func save_updateFailure_throwsSaveFailed() {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)

        fake.updateStatus = errSecParam
        fake.addStatus = errSecSuccess

        #expect(throws: KeychainCredentialStore.CredentialStoreError.saveFailed(status: errSecParam)) {
            try store.save(
                credentials: ProviderCredentials(username: "u@x.de", password: "pw"),
                serverHost: "booking.com"
            )
        }
    }

    @Test("KeychainCredentialStore save: Add Fehler (not success) → saveFailed")
    func save_addFailure_throwsSaveFailed() {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)

        fake.updateStatus = errSecItemNotFound
        fake.addStatus = errSecParam

        #expect(throws: KeychainCredentialStore.CredentialStoreError.saveFailed(status: errSecParam)) {
            try store.save(
                credentials: ProviderCredentials(username: "u@x.de", password: "pw"),
                serverHost: "booking.com"
            )
        }
    }

    @Test("KeychainCredentialStore accounts: unsupportedItem bei falschem CopyMatching-Returntyp")
    func accounts_unsupportedItem_throws() {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)

        fake.genericAttributeResults = "not-a-[[CFString:Any]]"

        #expect(throws: KeychainCredentialStore.CredentialStoreError.unsupportedItem) {
            _ = try store.accounts(serverHost: "booking.com")
        }
    }

    @Test("accounts: keine kSecAttrSynchronizableAny-Queries (keine Safari/iCloud-Dialoge)")
    func accounts_doesNotQuerySynchronizableAny() throws {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)

        _ = try store.accounts(serverHost: "booking.com")

        #expect(!fake.copyMatchingQueries.isEmpty)
        for dict in fake.copyMatchingQueries {
            #expect(!keychainQueryUsesSynchronizableAny(dict))
        }
    }

    @Test("accounts: kein unbeschränkter Internetpasswort-Scan ohne Server")
    func accounts_doesNotScanAllInternetPasswords() throws {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)

        _ = try store.accounts(serverHost: "booking.com")

        let internetQueries = fake.copyMatchingQueries.filter(keychainQueryIsInternetPassword)
        #expect(internetQueries.isEmpty)
    }

    @Test("accounts: Generic-Password-Lookup ohne Auth-UI")
    func accounts_usesGenericPasswordWithoutAuthUI() throws {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)

        _ = try store.accounts(serverHost: "booking.com")

        let genericQueries = fake.copyMatchingQueries.filter(keychainQueryIsGenericPassword)
        #expect(!genericQueries.isEmpty)
        for dict in genericQueries {
            #expect((dict[kSecAttrService] as? String) == KeychainCredentialQuery.service)
            #expect((dict[kSecUseAuthenticationUI] as? String) == (kSecUseAuthenticationUISkip as String))
            #expect(dict[kSecUseDataProtectionKeychain] as? Bool == true)
            #expect(dict[kSecReturnData] as? Bool == false)
        }
    }

    @Test("save: schreibt Generic Password in Data-Protection-Keychain")
    func save_writesGenericPasswordInDataProtectionKeychain() throws {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)
        fake.updateStatus = errSecItemNotFound
        fake.addStatus = errSecSuccess

        try store.save(
            credentials: ProviderCredentials(username: "u@x.de", password: "pw"),
            serverHost: "booking.com"
        )

        let dict = fake.lastAddQuery as? [CFString: Any]
        #expect(keychainQueryIsGenericPassword(dict ?? [:]))
        #expect((dict?[kSecAttrService] as? String) == KeychainCredentialQuery.service)
        #expect((dict?[kSecAttrAccount] as? String) == "booking.com\u{1f}u@x.de")
        #expect(dict?[kSecUseDataProtectionKeychain] as? Bool == true)
        #expect(!keychainQueryUsesSynchronizableAny(dict ?? [:]))
        #expect(keychainQueryIsInternetPassword(dict ?? [:]) == false)
    }

    @Test("credentials: lädt Generic-Password ohne Auth-UI")
    func credentials_loadsGenericPasswordWithoutAuthUI() throws {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)
        let account = KeychainCredentialAccount(serverHost: "booking.com", username: "u@x.de")
        fake.genericSecretByAccount[account.id] = Data("secret".utf8)

        let credentials = try store.credentials(for: account)
        #expect(credentials.username == "u@x.de")
        #expect(credentials.password == "secret")

        let secretQueries = fake.copyMatchingQueries.filter { dict in
            keychainQueryIsGenericPassword(dict) && dict[kSecReturnData] as? Bool == true
        }
        #expect(secretQueries.count == 1)
        #expect((secretQueries[0][kSecUseAuthenticationUI] as? String) == (kSecUseAuthenticationUISkip as String))
        #expect(keychainQueryUsesSynchronizableAny(secretQueries[0]) == false)
        #expect(fake.copyMatchingQueries.filter(keychainQueryIsInternetPassword).isEmpty)
    }
}

private func keychainQueryUsesSynchronizableAny(_ dict: [CFString: Any]) -> Bool {
    guard let value = dict[kSecAttrSynchronizable] else { return false }
    if let asString = value as? String {
        return asString == (kSecAttrSynchronizableAny as String)
    }
    return CFEqual(value as CFTypeRef, kSecAttrSynchronizableAny)
}

private func keychainQueryIsInternetPassword(_ dict: [CFString: Any]) -> Bool {
    guard let value = dict[kSecClass] else { return false }
    if let asString = value as? String {
        return asString == (kSecClassInternetPassword as String)
    }
    return CFEqual(value as CFTypeRef, kSecClassInternetPassword)
}

private func keychainQueryIsGenericPassword(_ dict: [CFString: Any]) -> Bool {
    guard let value = dict[kSecClass] else { return false }
    if let asString = value as? String {
        return asString == (kSecClassGenericPassword as String)
    }
    return CFEqual(value as CFTypeRef, kSecClassGenericPassword)
}
