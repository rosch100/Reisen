import Testing
import Foundation
import Security
@testable import ReisenProviders

struct KeychainCredentialSyncMigrationTests {
    @Test("migrate: local-only Item wird synchronizable und lokal gelöscht")
    func migrateLocalOnlyWhenNoSyncExists() {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)
        let accountID = KeychainCredentialAccount.makeID(serverHost: "booking.com", username: "u@x.de")
        fake.localOnlyAttributeResults = [
            [
                kSecAttrService as CFString: KeychainCredentialQuery.service,
                kSecAttrAccount as CFString: accountID,
            ],
        ]
        fake.localOnlySecretByAccount[accountID] = Data("local-secret".utf8)
        fake.updateStatus = errSecItemNotFound
        fake.addStatus = errSecSuccess
        fake.deleteStatus = errSecSuccess

        let migrated = store.migrateLocalOnlyToSynchronizable()

        #expect(migrated == 1)
        #expect(fake.genericSecretByAccount[accountID] == Data("local-secret".utf8))
        #expect(fake.localOnlySecretByAccount[accountID] == nil)
        #expect(fake.addCalls == 1)
        let add = fake.lastAddQuery as? [CFString: Any]
        #expect((add?[kSecAttrAccessGroup] as? String) == KeychainCredentialAccessGroup.value)
    }

    @Test("migrate: Default-Access-Group Item wird in shared Group gehoben")
    func migrateDefaultAccessGroupToShared() {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)
        let accountID = KeychainCredentialAccount.makeID(serverHost: "booking.com", username: "u@x.de")
        fake.genericAttributeResults = [
            [
                kSecAttrService as CFString: KeychainCredentialQuery.service,
                kSecAttrAccount as CFString: accountID,
                kSecAttrAccessGroup as CFString: "4N6AJL9EX5.app.voyenna.reisen",
            ],
        ]
        fake.genericSecretByAccount[accountID] = Data("legacy-secret".utf8)
        fake.genericAccessGroupByAccount[accountID] = "4N6AJL9EX5.app.voyenna.reisen"
        fake.updateStatus = errSecItemNotFound
        fake.addStatus = errSecSuccess
        fake.deleteStatus = errSecSuccess

        let migrated = store.migrateLocalOnlyToSynchronizable()

        #expect(migrated == 1)
        #expect(fake.deleteCalls >= 1)
        #expect(fake.addCalls == 1)
        let add = fake.lastAddQuery as? [CFString: Any]
        #expect((add?[kSecAttrAccessGroup] as? String) == KeychainCredentialAccessGroup.value)
        #expect(fake.genericSecretByAccount[accountID] == Data("legacy-secret".utf8))
    }

    @Test("migrate: Item bereits in shared Group wird nicht erneut geschrieben")
    func migrateSkipsWhenAlreadySharedAccessGroup() {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)
        let accountID = KeychainCredentialAccount.makeID(serverHost: "booking.com", username: "u@x.de")
        fake.genericAttributeResults = [
            [
                kSecAttrService as CFString: KeychainCredentialQuery.service,
                kSecAttrAccount as CFString: accountID,
                kSecAttrAccessGroup as CFString: KeychainCredentialAccessGroup.value,
            ],
        ]
        fake.genericSecretByAccount[accountID] = Data("shared-secret".utf8)

        let migrated = store.migrateLocalOnlyToSynchronizable()

        #expect(migrated == 0)
        #expect(fake.addCalls == 0)
        #expect(fake.deleteCalls == 0)
    }

    @Test("migrate: vorhandenes synchronizable Item wird nicht überschrieben")
    func migrateSkipsOverwriteWhenSyncExists() {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)
        let accountID = KeychainCredentialAccount.makeID(serverHost: "booking.com", username: "u@x.de")
        fake.localOnlyAttributeResults = [
            [
                kSecAttrService as CFString: KeychainCredentialQuery.service,
                kSecAttrAccount as CFString: accountID,
            ],
        ]
        fake.localOnlySecretByAccount[accountID] = Data("stale-local".utf8)
        fake.genericSecretByAccount[accountID] = Data("cloud-newer".utf8)
        fake.deleteStatus = errSecSuccess

        let migrated = store.migrateLocalOnlyToSynchronizable()

        #expect(migrated == 1)
        #expect(fake.addCalls == 0)
        #expect(fake.updateCalls == 0)
        #expect(fake.genericSecretByAccount[accountID] == Data("cloud-newer".utf8))
        #expect(fake.localOnlySecretByAccount[accountID] == nil)
    }

    @Test("migrate: zählt nicht wenn Delete fehlschlägt")
    func migrateDoesNotCountWhenDeleteFails() {
        let fake = FakeKeychainInternetPasswordAPI()
        let store = KeychainCredentialStore(keychain: fake)
        let accountID = KeychainCredentialAccount.makeID(serverHost: "booking.com", username: "u@x.de")
        fake.localOnlyAttributeResults = [
            [
                kSecAttrService as CFString: KeychainCredentialQuery.service,
                kSecAttrAccount as CFString: accountID,
            ],
        ]
        fake.localOnlySecretByAccount[accountID] = Data("local-secret".utf8)
        fake.updateStatus = errSecItemNotFound
        fake.addStatus = errSecSuccess
        fake.deleteStatus = errSecAuthFailed

        let migrated = store.migrateLocalOnlyToSynchronizable()

        #expect(migrated == 0)
        #expect(fake.deleteCalls == 1)
        #expect(fake.genericSecretByAccount[accountID] == Data("local-secret".utf8))
    }
}
