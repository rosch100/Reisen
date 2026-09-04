import Foundation
import Testing
import ReisenDomain

@Test func providerEnablement_ensuresEnabledFromUnset() async {
    let suiteName = "reisen.tests.providerEnablement.unset.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.removeObject(forKey: AppSettingsKeys.providerEnabledKey(for: .booking))

    await confirmation("providerEnabledDidChange") { confirmed in
        final class Once: @unchecked Sendable {
            var done = false
        }
        let once = Once()
        let token = NotificationCenter.default.addObserver(
            forName: .providerEnabledDidChange,
            object: nil,
            queue: nil
        ) { _ in
            guard !once.done else { return }
            once.done = true
            confirmed()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let changed = ProviderEnablement.ensureEnabled(.booking, defaults: defaults)
        #expect(changed)
        #expect(AppSettingsKeys.isProviderEnabled(.booking, defaults: defaults))
    }
}

@Test func providerEnablement_ensuresEnabledFromExplicitFalse() {
    let suiteName = "reisen.tests.providerEnablement.false.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(false, forKey: AppSettingsKeys.providerEnabledKey(for: .opodo))

    let changed = ProviderEnablement.ensureEnabled(.opodo, defaults: defaults)
    #expect(changed)
    #expect(AppSettingsKeys.isProviderEnabled(.opodo, defaults: defaults))
}

@Test func providerEnablement_noopWhenAlreadyEnabled() {
    let suiteName = "reisen.tests.providerEnablement.already.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: .check24))

    let changed = ProviderEnablement.ensureEnabled(.check24, defaults: defaults)
    #expect(!changed)
    #expect(AppSettingsKeys.isProviderEnabled(.check24, defaults: defaults))
}
