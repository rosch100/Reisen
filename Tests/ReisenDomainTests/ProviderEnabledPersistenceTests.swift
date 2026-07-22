import Testing
import Foundation
import ReisenDomain

@Test func providerEnabledPersistsFalseAndTrue() {
    let suiteName = "reisen.tests.providerEnabled.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let key = AppSettingsKeys.providerEnabledKey(for: .check24)
    #expect(defaults.object(forKey: key) == nil)

    defaults.set(false, forKey: key)
    #expect(defaults.bool(forKey: key) == false)

    defaults.set(true, forKey: key)
    #expect(defaults.bool(forKey: key) == true)
}
