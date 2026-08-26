import Testing
import Foundation
import ReisenDomain

@Test func providerAppAutoEnable_enablesDetectedProvidersWithDefaultPreference() {
    let suiteName = "reisen.tests.providerAppAutoEnable.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let changed = ProviderAppAutoEnable.applyIfNeeded(
        installedProviderIDs: [.booking, .airbnb],
        defaults: defaults
    )
    #expect(changed)
    #expect(AppSettingsKeys.isProviderEnabled(.booking, defaults: defaults))
    #expect(AppSettingsKeys.isProviderEnabled(.airbnb, defaults: defaults))
    #expect(defaults.bool(forKey: ProviderAppAutoEnable.appliedKey(for: .booking)))
    #expect(defaults.bool(forKey: ProviderAppAutoEnable.appliedKey(for: .airbnb)))
}

@Test func providerAppAutoEnable_respectsExplicitDisableBeforeFirstRun() {
    let suiteName = "reisen.tests.providerAppAutoEnable.explicit.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(false, forKey: AppSettingsKeys.providerEnabledKey(for: .booking))

    let changed = ProviderAppAutoEnable.applyIfNeeded(
        installedProviderIDs: [.booking],
        defaults: defaults
    )
    #expect(!changed)
    #expect(!AppSettingsKeys.isProviderEnabled(.booking, defaults: defaults))
    #expect(defaults.bool(forKey: ProviderAppAutoEnable.appliedKey(for: .booking)))
}

@Test func providerAppAutoEnable_respectsManualDisableAfterFirstRun() {
    let suiteName = "reisen.tests.providerAppAutoEnable.disable.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    _ = ProviderAppAutoEnable.applyIfNeeded(installedProviderIDs: [.booking], defaults: defaults)
    defaults.set(false, forKey: AppSettingsKeys.providerEnabledKey(for: .booking))

    let changed = ProviderAppAutoEnable.applyIfNeeded(installedProviderIDs: [.booking], defaults: defaults)
    #expect(!changed)
    #expect(!AppSettingsKeys.isProviderEnabled(.booking, defaults: defaults))
}

@Test func providerAppAutoEnable_doesNothingWithoutInstalledApps() {
    let suiteName = "reisen.tests.providerAppAutoEnable.empty.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(false, forKey: AppSettingsKeys.providerEnabledKey(for: .check24))

    let changed = ProviderAppAutoEnable.applyIfNeeded(installedProviderIDs: [], defaults: defaults)
    #expect(!changed)
    #expect(!AppSettingsKeys.isProviderEnabled(.check24, defaults: defaults))
}
