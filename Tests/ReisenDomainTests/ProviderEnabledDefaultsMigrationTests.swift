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

@Test func providerEnabledDefaultsMigration_existingInstallMaterializesFormerDefaultTrue() {
    let suiteName = "reisen.tests.providerEnabled.migration.existing.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    // Vorherige Installation ohne explizite Provider-Keys (implizit alle aktiv).
    defaults.set(240.0, forKey: AppSettingsKeys.sidebarColumnWidth)

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
    defaults.set(7, forKey: AppSettingsKeys.leadTimesDays)

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
