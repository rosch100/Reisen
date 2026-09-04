import Testing
import Foundation
import ReisenDomain

@Test func providerEnabledDefaultsMigration_freshInstallLeavesProvidersDisabled() {
    let suiteName = "reisen.tests.providerEnabled.migration.fresh.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let didMigrate = ProviderEnabledDefaultsMigration.migrateIfNeeded(
        syncProviderIDs: [.check24, .opodo],
        defaults: defaults
    )

    #expect(didMigrate)
    #expect(defaults.bool(forKey: ProviderEnabledDefaultsMigration.migratedKey))
    #expect(!AppSettingsKeys.isProviderEnabled(.check24, defaults: defaults))
    #expect(!AppSettingsKeys.isProviderEnabled(.opodo, defaults: defaults))
    #expect(defaults.object(forKey: AppSettingsKeys.providerEnabledKey(for: .check24)) == nil)
}

@Test func providerEnabledDefaultsMigration_uiOnlyPrefsDoNotMaterializeAllOn() {
    let suiteName = "reisen.tests.providerEnabled.migration.uiOnly.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    // Nur UI-/Settings-Reste ohne konfiguriertes Provider-Konto → Frischstart-Opt-in.
    defaults.set(240.0, forKey: AppSettingsKeys.sidebarColumnWidth)
    defaults.set("", forKey: AppSettingsKeys.preferredKeychainAccountKey(for: .check24))

    let didMigrate = ProviderEnabledDefaultsMigration.migrateIfNeeded(
        syncProviderIDs: [.check24, .opodo],
        defaults: defaults
    )

    #expect(didMigrate)
    #expect(!AppSettingsKeys.isProviderEnabled(.check24, defaults: defaults))
    #expect(!AppSettingsKeys.isProviderEnabled(.opodo, defaults: defaults))
    #expect(defaults.object(forKey: AppSettingsKeys.providerEnabledKey(for: .check24)) == nil)
}

@Test func providerEnabledDefaultsMigration_configuredAccountMaterializesFormerDefaultTrue() {
    let suiteName = "reisen.tests.providerEnabled.migration.configuredAccount.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    // Bestandskunde: mind. ein Provider-Konto gewählt (Host\u{1F}Username).
    defaults.set(
        "check24.de\u{1F}user@example.com",
        forKey: AppSettingsKeys.preferredKeychainAccountKey(for: .check24)
    )

    let didMigrate = ProviderEnabledDefaultsMigration.migrateIfNeeded(
        syncProviderIDs: [.check24, .opodo],
        defaults: defaults
    )

    #expect(didMigrate)
    #expect(AppSettingsKeys.isProviderEnabled(.check24, defaults: defaults))
    #expect(AppSettingsKeys.isProviderEnabled(.opodo, defaults: defaults))
    #expect(defaults.bool(forKey: AppSettingsKeys.providerEnabledKey(for: .check24)))
}

@Test func providerEnabledDefaultsMigration_preservesExplicitFalseOnUpgrade() {
    let suiteName = "reisen.tests.providerEnabled.migration.explicitFalse.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(false, forKey: AppSettingsKeys.providerEnabledKey(for: .check24))
    defaults.set(
        "opodo.de\u{1F}user@example.com",
        forKey: AppSettingsKeys.preferredKeychainAccountKey(for: .opodo)
    )

    _ = ProviderEnabledDefaultsMigration.migrateIfNeeded(
        syncProviderIDs: [.check24, .opodo],
        defaults: defaults
    )

    #expect(!AppSettingsKeys.isProviderEnabled(.check24, defaults: defaults))
    #expect(AppSettingsKeys.isProviderEnabled(.opodo, defaults: defaults))
}

@Test func providerEnabledDefaultsMigration_isIdempotent() {
    let suiteName = "reisen.tests.providerEnabled.migration.idempotent.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    #expect(ProviderEnabledDefaultsMigration.migrateIfNeeded(
        syncProviderIDs: [.check24],
        defaults: defaults
    ))
    #expect(!ProviderEnabledDefaultsMigration.migrateIfNeeded(
        syncProviderIDs: [.check24],
        defaults: defaults
    ))
}

@Test func providerEnabledDefaultsMigration_repairsFalsePositiveAllOnWithoutCredentials() {
    let suiteName = "reisen.tests.providerEnabled.migration.repair.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let syncIDs: [ProviderID] = [.check24, .opodo, .booking]
    defaults.set(true, forKey: ProviderEnabledDefaultsMigration.migratedKey)
    for providerID in syncIDs {
        defaults.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: providerID))
    }
    defaults.set("", forKey: AppSettingsKeys.preferredKeychainAccountKey(for: .check24))
    ProviderFirstLaunchSetup.markCompleted(defaults: defaults)

    let didRepair = ProviderEnabledDefaultsMigration.repairFalsePositiveAllOnIfNeeded(
        syncProviderIDs: syncIDs,
        defaults: defaults
    )

    #expect(didRepair)
    #expect(defaults.bool(forKey: ProviderEnabledDefaultsMigration.falsePositiveRepairKey))
    for providerID in syncIDs {
        #expect(!AppSettingsKeys.isProviderEnabled(providerID, defaults: defaults))
        #expect(defaults.object(forKey: AppSettingsKeys.providerEnabledKey(for: providerID)) == nil)
    }
    #expect(ProviderFirstLaunchSetup.shouldPresent(defaults: defaults))
}

@Test func providerEnabledDefaultsMigration_repairSkipsWhenPreferredAccountConfigured() {
    let suiteName = "reisen.tests.providerEnabled.migration.repairSkip.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(true, forKey: ProviderEnabledDefaultsMigration.migratedKey)
    defaults.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: .check24))
    defaults.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: .opodo))
    defaults.set(
        "check24.de\u{1F}user@example.com",
        forKey: AppSettingsKeys.preferredKeychainAccountKey(for: .check24)
    )

    let didRepair = ProviderEnabledDefaultsMigration.repairFalsePositiveAllOnIfNeeded(
        syncProviderIDs: [.check24, .opodo],
        defaults: defaults
    )

    #expect(!didRepair)
    #expect(AppSettingsKeys.isProviderEnabled(.check24, defaults: defaults))
    #expect(AppSettingsKeys.isProviderEnabled(.opodo, defaults: defaults))
}
