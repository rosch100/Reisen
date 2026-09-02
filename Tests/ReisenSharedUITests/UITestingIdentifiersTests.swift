import Testing
import ReisenSharedUI
import ReisenData

@Test func uiTestingIdentifiers_areStableAndSeeded() {
    #expect(UITestingIdentifiers.sidebar == "reisen.sidebar")
    #expect(UITestingIdentifiers.detail == "reisen.detail")
    #expect(UITestingIdentifiers.inspector == "reisen.inspector")
    #expect(UITestingIdentifiers.deleteTripMenu == "reisen.action.delete-trip")
    #expect(UITestingIdentifiers.deleteBookingMenu == "reisen.action.delete-booking")
    #expect(UITestingIdentifiers.sidebarExpandBookings == "reisen.action.expand-sidebar-bookings")
    #expect(UITestingIdentifiers.bookingCreateDraftTimeline == "reisen.booking.create-draft.timeline")
    #expect(UITestingIdentifiers.bookingCreateDraftSidebar == "reisen.booking.create-draft.sidebar")
    #expect(UITestingIdentifiers.seededTripRow == UITestingIdentifiers.tripRow(UITestingSeed.tripID))
    #expect(UITestingIdentifiers.seededBookingRow == UITestingIdentifiers.bookingRow(UITestingSeed.bookingID))
}
