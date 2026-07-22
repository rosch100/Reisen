import Testing
import Foundation
import Security
@testable import ReisenProviders

final class FakeKeychainInternetPasswordAPI: KeychainInternetPasswordKeychainAPI {
    var copyMatchingCallCount: Int = 0

    var directResultsByServer: [String: [[CFString: Any]]] = [:]
    var fullScanResults: Any = [[CFString: Any]]()

    var fullScanStatus: OSStatus = errSecSuccess
    var directStatus: OSStatus = errSecSuccess

    var updateCalls: Int = 0
    var addCalls: Int = 0

    var updateStatus: OSStatus = errSecSuccess
    var addStatus: OSStatus = errSecSuccess

    private(set) var lastUpdateExistingQuery: CFDictionary?
    private(set) var lastAddQuery: CFDictionary?

    func itemCopyMatching(query: CFDictionary) -> (status: OSStatus, item: CFTypeRef?) {
        copyMatchingCallCount += 1

        if let dict = query as? [CFString: Any],
           let server = dict[kSecAttrServer] as? String {
            let results = directResultsByServer[server] ?? []
            return (directStatus, results as CFTypeRef)
        }

        // Fallback full scan: no server attribute in query.
        if let typed = fullScanResults as? [[CFString: Any]] {
            return (fullScanStatus, typed as CFTypeRef)
        }
        // Unsupported type for `[[CFString: Any]]` cast.
        return (fullScanStatus, fullScanResults as? CFTypeRef)
    }

    func itemUpdate(existingQuery: CFDictionary, update: CFDictionary) -> OSStatus {
        updateCalls += 1
        lastUpdateExistingQuery = existingQuery
        return updateStatus
    }

    func itemAdd(add: CFDictionary) -> OSStatus {
        addCalls += 1
        lastAddQuery = add
        return addStatus
    }
}

extension FakeKeychainInternetPasswordAPI: @unchecked Sendable {}

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

        fake.directResultsByServer["booking.com"] = [
            [kSecAttrServer as CFString: "booking.com", kSecAttrAccount as CFString: "b@a.de"],
            [kSecAttrServer as CFString: "booking.com", kSecAttrAccount as CFString: "a@b.de"],
            // Duplicate of first entry (same server + username).
            [kSecAttrServer as CFString: "booking.com", kSecAttrAccount as CFString: "b@a.de"],
        ]

        let accounts = try store.accounts(serverHost: "booking.com")
        #expect(accounts.count == 2)
        #expect(accounts.map(\.username) == ["a@b.de", "b@a.de"])
    }

    @Test("KeychainCredentialStore accounts: Fallback Full-Scan wird genutzt wenn direkte Matches leer sind")
    func accounts_fallbackFullScan_usedWhenDirectEmpty() throws {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)

        fake.directResultsByServer["booking.com"] = []
        fake.fullScanResults = [
            [kSecAttrServer as CFString: "secure.booking.com", kSecAttrAccount as CFString: "user1@x.de"],
            [kSecAttrServer as CFString: "other.com", kSecAttrAccount as CFString: "ignored@x.de"],
        ]

        let accounts = try store.accounts(serverHost: "booking.com")
        #expect(accounts.count == 1)
        #expect(accounts.first?.serverHost == "secure.booking.com")
        #expect(accounts.first?.username == "user1@x.de")
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
            #expect((dict[kSecAttrAccount] as? String) == "u@x.de")
            #expect((dict[kSecAttrServer] as? String) == "booking.com")
        } else {
            #expect(false)
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
            #expect((dict[kSecAttrAccount] as? String) == "u2@x.de")
        } else {
            #expect(false)
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

        fake.directResultsByServer["booking.com"] = []
        fake.fullScanResults = "not-a-[[CFString:Any]]"

        #expect(throws: KeychainCredentialStore.CredentialStoreError.unsupportedItem) {
            _ = try store.accounts(serverHost: "booking.com")
        }
    }
}

