import Testing
import Foundation
import ReisenDomain

@Test func appSettingsDefaults_overrideRoutesIsProviderEnabled() {
    let suiteName = "reisen.tests.appSettingsDefaults.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer {
        AppSettingsDefaults.installOverride(nil)
        defaults.removePersistentDomain(forName: suiteName)
    }

    defaults.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: .check24))
    AppSettingsDefaults.installOverride(defaults)

    #expect(AppSettingsKeys.isProviderEnabled(.check24))
    #expect(!AppSettingsKeys.isProviderEnabled(.opodo))
}
