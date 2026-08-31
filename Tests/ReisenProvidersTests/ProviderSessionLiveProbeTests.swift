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

@Test func providerSessionLiveProbeShouldStartCheck24Policy() {
    let home = URL(string: "https://www.check24.de/")!
    let product = URL(string: "https://www.check24.de/hotel/irgendwas/")!

    #expect(
        ProviderSessionLiveProbe.shouldStart(
            .shouldProbeCheck24,
            sessionAlreadyReady: false,
            url: home
        )
    )
    #expect(
        !ProviderSessionLiveProbe.shouldStart(
            .shouldProbeCheck24,
            sessionAlreadyReady: true,
            url: product
        )
    )
    // Logout → Marketing-Homepage: trotz grüner Ampel erneut proben.
    #expect(
        ProviderSessionLiveProbe.shouldStart(
            .shouldProbeCheck24,
            sessionAlreadyReady: true,
            url: home
        )
    )
    #expect(ProviderSessionLiveProbe.shouldStart(.shouldProbeOpodo, sessionAlreadyReady: true))
    #expect(!ProviderSessionLiveProbe.shouldStart(.needsLogin, sessionAlreadyReady: false))
}
