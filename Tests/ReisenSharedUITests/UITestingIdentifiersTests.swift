import Testing
import ReisenSharedUI
import ReisenData

@Test func uiTestingIdentifiers_areStableAndSeeded() {
    #expect(UITestingIdentifiers.sidebar == "reisen.sidebar")
    #expect(UITestingIdentifiers.detail == "reisen.detail")
    #expect(UITestingIdentifiers.inspector == "reisen.inspector")
    #expect(UITestingIdentifiers.seededTripRow == UITestingIdentifiers.tripRow(UITestingSeed.tripID))
    #expect(UITestingIdentifiers.seededBookingRow == UITestingIdentifiers.bookingRow(UITestingSeed.bookingID))
}
