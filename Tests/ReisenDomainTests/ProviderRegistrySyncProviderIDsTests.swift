import Testing
import Foundation
import ReisenDomain

@MainActor
private struct FakeTravelProvider: TravelProvider {
    let id: ProviderID
    let displayName: String

    func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog {
        ProviderCatalog(bookings: [])
    }

    func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        ProviderBookingEnrichment()
    }

    func needsDraftEnrichment(
        draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool {
        false
    }
}

@Test @MainActor func syncProviderIDs_reflectsRegisteredProviders() {
    let fakeID = ProviderID("fake")
    let registry = ProviderRegistry(providers: [
        FakeTravelProvider(id: .check24, displayName: "Check24"),
        FakeTravelProvider(id: fakeID, displayName: "Fake Provider"),
    ])

    #expect(registry.syncProviderIDs == [.check24, fakeID])
}

@Test @MainActor func enabledSyncProviderIDs_filtersDisabledProviders() {
    let suiteName = "reisen.tests.registry.enabled.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let registry = ProviderRegistry(providers: [
        FakeTravelProvider(id: .check24, displayName: "Check24"),
        FakeTravelProvider(id: .getYourGuide, displayName: "GetYourGuide"),
    ])

    defaults.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: .check24))
    defaults.set(false, forKey: AppSettingsKeys.providerEnabledKey(for: .getYourGuide))

    #expect(registry.enabledSyncProviderIDs(defaults: defaults) == [.check24])
}
