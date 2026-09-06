import Testing
import Foundation
import ReisenDomain

private func makeIsolatedDefaults() -> (UserDefaults, String)? {
    let suiteName = "reisen.tests.providerFirstLaunch.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
    return (defaults, suiteName)
}

@Test func providerFirstLaunchSetup_shouldPresent_whenHideOffAndNoEnabledProvider() {
    guard let (defaults, suiteName) = makeIsolatedDefaults() else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    #expect(defaults.object(forKey: AppSettingsKeys.providerSetupDeferred) == nil)
    #expect(ProviderFirstLaunchSetup.shouldPresent(defaults: defaults, syncProviderIDs: [.check24, .opodo]))
    #expect(!ProviderFirstLaunchSetup.isInitialSetupHidden(defaults: defaults))
}

@Test func providerFirstLaunchSetup_shouldPresent_falseWhenHideOnEvenIfNoProviders() {
    guard let (defaults, suiteName) = makeIsolatedDefaults() else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    ProviderFirstLaunchSetup.setInitialSetupHidden(true, defaults: defaults)

    #expect(ProviderFirstLaunchSetup.isInitialSetupHidden(defaults: defaults))
    #expect(!ProviderFirstLaunchSetup.shouldPresent(defaults: defaults, syncProviderIDs: [.check24, .opodo]))
    #expect(defaults.bool(forKey: AppSettingsKeys.providerSetupDeferred))
}

@Test func providerFirstLaunchSetup_shouldPresent_falseWhenAnyProviderEnabled() {
    guard let (defaults, suiteName) = makeIsolatedDefaults() else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: .check24))

    #expect(!ProviderFirstLaunchSetup.shouldPresent(defaults: defaults, syncProviderIDs: [.check24, .opodo]))
}

@Test func providerFirstLaunchSetup_shouldPresent_trueWhenCompletedButHideOffAndNoProviders() {
    guard let (defaults, suiteName) = makeIsolatedDefaults() else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    ProviderFirstLaunchSetup.markCompleted(defaults: defaults)

    #expect(ProviderFirstLaunchSetup.shouldPresent(defaults: defaults, syncProviderIDs: [.check24, .opodo]))
}

@Test func providerFirstLaunchSetup_ohneBuchungsportale_hidesCompletesAndLeavesProvidersOff() {
    guard let (defaults, suiteName) = makeIsolatedDefaults() else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let syncIDs: [ProviderID] = [.check24, .opodo]
    defaults.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: .check24))

    ProviderFirstLaunchSetup.completeWithoutPortals(syncProviderIDs: syncIDs, defaults: defaults)

    #expect(ProviderFirstLaunchSetup.isInitialSetupHidden(defaults: defaults))
    #expect(defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted))
    #expect(!AppSettingsKeys.isProviderEnabled(.check24, defaults: defaults))
    #expect(!AppSettingsKeys.isProviderEnabled(.opodo, defaults: defaults))
    #expect(!ProviderFirstLaunchSetup.shouldPresent(defaults: defaults, syncProviderIDs: syncIDs))
}

@Test func providerFirstLaunchSetup_emptyContinue_marksCompletedAndHidesWithoutEnablingProviders() {
    guard let (defaults, suiteName) = makeIsolatedDefaults() else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let syncIDs: [ProviderID] = [.check24, .opodo]
    ProviderFirstLaunchSetup.applySelection(
        enabledIDs: [],
        syncProviderIDs: syncIDs,
        defaults: defaults
    )
    ProviderFirstLaunchSetup.completeWithoutPortals(syncProviderIDs: syncIDs, defaults: defaults)

    #expect(!ProviderFirstLaunchSetup.shouldPresent(defaults: defaults, syncProviderIDs: syncIDs))
    #expect(defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted))
    #expect(ProviderFirstLaunchSetup.isInitialSetupHidden(defaults: defaults))
    #expect(!AppSettingsKeys.isProviderEnabled(.check24, defaults: defaults))
    #expect(!AppSettingsKeys.isProviderEnabled(.opodo, defaults: defaults))
}

@Test func providerFirstLaunchSetup_setInitialSetupHidden_offAllowsPresentWhenNoProviders() {
    guard let (defaults, suiteName) = makeIsolatedDefaults() else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    ProviderFirstLaunchSetup.completeWithoutPortals(
        syncProviderIDs: [.check24],
        defaults: defaults
    )
    ProviderFirstLaunchSetup.setInitialSetupHidden(false, defaults: defaults)

    #expect(!ProviderFirstLaunchSetup.isInitialSetupHidden(defaults: defaults))
    #expect(ProviderFirstLaunchSetup.shouldPresent(defaults: defaults, syncProviderIDs: [.check24]))
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

@Test func providerFirstLaunchSetup_bootstrap_skipsWhenOnlyExplicitFalseKeysExist() {
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

    #expect(!didBootstrap)
    #expect(!defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted))
    #expect(ProviderFirstLaunchSetup.shouldPresent(defaults: defaults, syncProviderIDs: [.check24, .opodo]))
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
    #expect(!ProviderFirstLaunchSetup.shouldPresent(defaults: defaults, syncProviderIDs: [.check24, .opodo]))
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
    #expect(ProviderFirstLaunchSetup.shouldPresent(defaults: defaults, syncProviderIDs: [.check24, .opodo]))
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
