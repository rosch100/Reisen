import Foundation
import Testing
import ReisenAppCore
import ReisenDomain

/// `ProviderEnablement.ensureEnabled` benachrichtigt Beobachter; Hub legt danach den Slot an.
@MainActor
@Test func providerEnablement_thenHubSyncCreatesNeedsLoginSlot() {
    let suiteName = "reisen.tests.providerEnablement.hub.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(false, forKey: AppSettingsKeys.providerEnabledKey(for: .booking))

    let hub = ProviderSessionHub()
    hub.syncEnabledProviders([])
    #expect(hub.status(for: .booking) == nil)

    final class Flag: @unchecked Sendable {
        var notified = false
    }
    let flag = Flag()
    let token = NotificationCenter.default.addObserver(
        forName: .providerEnabledDidChange,
        object: nil,
        queue: nil
    ) { _ in
        flag.notified = true
        hub.syncEnabledProviders(
            Set(ProviderID.syncProviderIDs.filter {
                AppSettingsKeys.isProviderEnabled($0, defaults: defaults)
            })
        )
    }
    defer { NotificationCenter.default.removeObserver(token) }

    #expect(ProviderEnablement.ensureEnabled(.booking, defaults: defaults))
    #expect(flag.notified)
    #expect(hub.status(for: .booking) == .needsLogin)
}
