import Foundation
import Testing

@testable import ReisenProviders

@Test func providerSessionLiveProbePrepareMapsHeuristic() {
    let opodo = ProviderSessionLiveProbe.prepare(.shouldProbeOpodo, sessionAlreadyReady: false)
    #expect(opodo != nil)
    #expect(opodo?.skipsAccountPage == true)

    let traveloka = ProviderSessionLiveProbe.prepare(.shouldProbeTraveloka, sessionAlreadyReady: false)
    #expect(traveloka != nil)
    #expect(traveloka?.skipsAccountPage == true)

    let billiger = ProviderSessionLiveProbe.prepare(
        .shouldProbeBilligerMietwagen,
        sessionAlreadyReady: false
    )
    #expect(billiger != nil)
    #expect(billiger?.skipsAccountPage == false)

    let check24 = ProviderSessionLiveProbe.prepare(.shouldProbeCheck24, sessionAlreadyReady: false)
    #expect(check24 != nil)
    #expect(check24?.skipsAccountPage == false)

    #expect(ProviderSessionLiveProbe.prepare(.sessionReady, sessionAlreadyReady: false) == nil)
    #expect(ProviderSessionLiveProbe.prepare(.needsLogin, sessionAlreadyReady: false) == nil)
    #expect(ProviderSessionLiveProbe.prepare(.unknown, sessionAlreadyReady: false) == nil)
}

@Test func providerSessionLiveProbePrepareCheck24Policy() {
    let home = URL(string: "https://www.check24.de/")!
    let product = URL(string: "https://www.check24.de/hotel/irgendwas/")!

    #expect(
        ProviderSessionLiveProbe.prepare(
            .shouldProbeCheck24,
            sessionAlreadyReady: false,
            url: home
        ) != nil
    )
    #expect(
        ProviderSessionLiveProbe.prepare(
            .shouldProbeCheck24,
            sessionAlreadyReady: true,
            url: product
        ) == nil
    )
    // Logout → Marketing-Homepage: trotz grüner Ampel erneut proben.
    #expect(
        ProviderSessionLiveProbe.prepare(
            .shouldProbeCheck24,
            sessionAlreadyReady: true,
            url: home
        ) != nil
    )
    #expect(ProviderSessionLiveProbe.prepare(.shouldProbeOpodo, sessionAlreadyReady: true) != nil)
    #expect(ProviderSessionLiveProbe.prepare(.needsLogin, sessionAlreadyReady: false) == nil)
}
