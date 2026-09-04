import Testing
import Foundation
import ReisenDomain

private func makeIsolatedDefaults() -> (UserDefaults, String)? {
    let suiteName = "reisen.tests.providerFirstLaunch.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
    return (defaults, suiteName)
}

@Test func providerFirstLaunchSetup_shouldPresent_whenNeitherFlagSet() {
    guard let (defaults, suiteName) = makeIsolatedDefaults() else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    #expect(ProviderFirstLaunchSetup.shouldPresent(defaults: defaults))
}

@Test func providerFirstLaunchSetup_shouldPresent_falseWhenCompleted() {
    guard let (defaults, suiteName) = makeIsolatedDefaults() else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    ProviderFirstLaunchSetup.markCompleted(defaults: defaults)

    #expect(!ProviderFirstLaunchSetup.shouldPresent(defaults: defaults))
    #expect(defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted))
}

@Test func providerFirstLaunchSetup_shouldPresent_falseWhenDeferred() {
    guard let (defaults, suiteName) = makeIsolatedDefaults() else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    ProviderFirstLaunchSetup.markDeferred(defaults: defaults)

    #expect(!ProviderFirstLaunchSetup.shouldPresent(defaults: defaults))
    #expect(defaults.bool(forKey: AppSettingsKeys.providerSetupDeferred))
}

@Test func providerFirstLaunchSetup_shouldPresent_falseWhenBothFlagsSet() {
    guard let (defaults, suiteName) = makeIsolatedDefaults() else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    ProviderFirstLaunchSetup.markCompleted(defaults: defaults)
    ProviderFirstLaunchSetup.markDeferred(defaults: defaults)

    #expect(!ProviderFirstLaunchSetup.shouldPresent(defaults: defaults))
}

@Test func providerFirstLaunchSetup_applySelection_setsEnabledExplicitly() {
    guard let (defaults, suiteName) = makeIsolatedDefaults() else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let syncIDs: [ProviderID] = [.check24, .opodo, .booking]
    ProviderFirstLaunchSetup.applySelection(
        enabledIDs: [.check24, .booking],
        syncProviderIDs: syncIDs,
        defaults: defaults
    )

    #expect(AppSettingsKeys.isProviderEnabled(.check24, defaults: defaults))
    #expect(!AppSettingsKeys.isProviderEnabled(.opodo, defaults: defaults))
    #expect(AppSettingsKeys.isProviderEnabled(.booking, defaults: defaults))
    #expect(defaults.object(forKey: AppSettingsKeys.providerEnabledKey(for: .opodo)) != nil)
    #expect(defaults.bool(forKey: AppSettingsKeys.providerEnabledKey(for: .opodo)) == false)
}

@Test func providerFirstLaunchSetup_bootstrap_marksCompletedWhenProviderKeyExists() {
    guard let (defaults, suiteName) = makeIsolatedDefaults() else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(false, forKey: AppSettingsKeys.providerEnabledKey(for: .check24))

    let didBootstrap = ProviderFirstLaunchSetup.bootstrapCompletedIfExistingProviders(
        defaults: defaults,
        syncProviderIDs: [.check24, .opodo]
    )

    #expect(didBootstrap)
    #expect(defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted))
    #expect(!ProviderFirstLaunchSetup.shouldPresent(defaults: defaults))
}

@Test func providerFirstLaunchSetup_bootstrap_marksCompletedWhenProviderEnabled() {
    guard let (defaults, suiteName) = makeIsolatedDefaults() else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: .opodo))

    let didBootstrap = ProviderFirstLaunchSetup.bootstrapCompletedIfExistingProviders(
        defaults: defaults,
        syncProviderIDs: [.check24, .opodo]
    )

    #expect(didBootstrap)
    #expect(defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted))
}

@Test func providerFirstLaunchSetup_bootstrap_skipsFreshInstallWithoutProviderKeys() {
    guard let (defaults, suiteName) = makeIsolatedDefaults() else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(240.0, forKey: AppSettingsKeys.sidebarColumnWidth)

    let didBootstrap = ProviderFirstLaunchSetup.bootstrapCompletedIfExistingProviders(
        defaults: defaults,
        syncProviderIDs: [.check24, .opodo]
    )

    #expect(!didBootstrap)
    #expect(!defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted))
    #expect(ProviderFirstLaunchSetup.shouldPresent(defaults: defaults))
}

@Test func providerFirstLaunchSetup_bootstrap_isIdempotentWhenAlreadyCompleted() {
    guard let (defaults, suiteName) = makeIsolatedDefaults() else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: .check24))
    ProviderFirstLaunchSetup.markCompleted(defaults: defaults)

    let didBootstrap = ProviderFirstLaunchSetup.bootstrapCompletedIfExistingProviders(
        defaults: defaults,
        syncProviderIDs: [.check24]
    )

    #expect(!didBootstrap)
    #expect(defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted))
}
