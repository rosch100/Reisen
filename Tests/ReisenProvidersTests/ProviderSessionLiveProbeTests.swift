import Foundation
import Testing

@testable import ReisenProviders

@Test func providerSessionLiveProbeAppliesMatchesHeuristic() {
    #expect(ProviderSessionLiveProbe.applies(to: .shouldProbeOpodo) != nil)
    #expect(ProviderSessionLiveProbe.applies(to: .shouldProbeTraveloka) != nil)
    #expect(ProviderSessionLiveProbe.applies(to: .shouldProbeBilligerMietwagen) != nil)
    #expect(ProviderSessionLiveProbe.applies(to: .shouldProbeCheck24) != nil)
    #expect(ProviderSessionLiveProbe.applies(to: .sessionReady) == nil)
    #expect(ProviderSessionLiveProbe.applies(to: .needsLogin) == nil)
    #expect(ProviderSessionLiveProbe.applies(to: .unknown) == nil)
}

@Test func providerSessionLiveProbeSkipsAccountPageOnlyForOpodoTraveloka() {
    #expect(ProviderSessionLiveProbe.skipsAccountPageProbe(.shouldProbeOpodo))
    #expect(ProviderSessionLiveProbe.skipsAccountPageProbe(.shouldProbeTraveloka))
    #expect(!ProviderSessionLiveProbe.skipsAccountPageProbe(.shouldProbeBilligerMietwagen))
    #expect(!ProviderSessionLiveProbe.skipsAccountPageProbe(.shouldProbeCheck24))
}
