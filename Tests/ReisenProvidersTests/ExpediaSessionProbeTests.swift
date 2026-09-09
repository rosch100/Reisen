import Foundation
import Testing
import ReisenProviders

@Test func expediaSessionProbeAppliesOnlyToExpediaHosts() {
    #expect(ExpediaSessionProbe.applies(to: URL(string: "https://www.expedia.de/trips")!))
    #expect(ExpediaSessionProbe.applies(to: URL(string: "https://expedia.de/login")!))
    #expect(!ExpediaSessionProbe.applies(to: URL(string: "https://www.booking.com/trips")!))
    #expect(ExpediaSessionProbe.isPortalHost("www.expedia.de"))
    #expect(ExpediaSessionProbe.isPortalHost("expedia.de"))
    #expect(!ExpediaSessionProbe.isPortalHost("booking.com"))
}

@Test func expediaSessionProbeDetectsManageBookingURL() {
    let manage = URL(
        string: "https://www.expedia.de/trips/egti-x/details/abc/manage-booking"
    )
    let detail = URL(string: "https://www.expedia.de/trips/egti-x/details/abc")
    #expect(ExpediaSessionProbe.isManageBookingURL(manage))
    #expect(!ExpediaSessionProbe.isManageBookingURL(detail))
    #expect(!ExpediaSessionProbe.isManageBookingURL(URL(string: "https://www.booking.com/manage-booking")))
}

@Test func expediaSessionProbeDetectsLoginHTML() {
    #expect(ExpediaSessionProbe.isLoginHTML("<form action=\"/login\"><input type=\"password\">"))
    #expect(ExpediaSessionProbe.isLoginHTML("arkoselabs challenge"))
    #expect(!ExpediaSessionProbe.isLoginHTML("<h1>Meine Reisen</h1><a href=\"/trips/egti-x\">"))
}

@Test func expediaTripsIsNotBlindSessionReady() {
    let trips = URL(string: "https://www.expedia.de/trips")!
    let classified = ProviderSessionStatusResolver.classify(trips)
    #expect(classified != .sessionReady)
    #expect(classified == .shouldProbeExpedia)
}

@Test func expediaLoginAlsoProbesSession() {
    let login = URL(string: "https://www.expedia.de/login")!
    #expect(ProviderSessionStatusResolver.classify(login) == .shouldProbeExpedia)
}
