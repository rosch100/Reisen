import Testing
import Foundation
import ReisenDomain

@Test func isProviderEnabled_defaultsToTrueWhenKeyMissing() {
    let suiteName = "reisen.tests.providerEnabled.lookup.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    #expect(AppSettingsKeys.isProviderEnabled(.check24, defaults: defaults))
}

@Test func isProviderEnabled_respectsExplicitFalse() {
    let suiteName = "reisen.tests.providerEnabled.lookup.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let key = AppSettingsKeys.providerEnabledKey(for: .getYourGuide)
    defaults.set(false, forKey: key)
    #expect(!AppSettingsKeys.isProviderEnabled(.getYourGuide, defaults: defaults))
}
