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
    #expect(UITestingIdentifiers.tripMultiSelectionSummary == "reisen.trip.multi-selection-summary")
    #expect(UITestingIdentifiers.openBookingMultiSelectionSummary == "reisen.open.multi-selection-summary")
    #expect(UITestingIdentifiers.tripBookingMultiSelectionSummary == "reisen.trip-booking.multi-selection-summary")
    #expect(UITestingIdentifiers.openBookingsContent == "reisen.open-bookings.content")
    #expect(UITestingIdentifiers.seededTripRow == UITestingIdentifiers.tripRow(UITestingSeed.tripID))
    #expect(UITestingIdentifiers.seededBookingRow == UITestingIdentifiers.bookingRow(UITestingSeed.bookingID))
    #expect(UITestingIdentifiers.seededBookingRow2 == UITestingIdentifiers.bookingRow(UITestingSeed.bookingID2))
    #expect(UITestingIdentifiers.seededTimelineBookingRow == UITestingIdentifiers.timelineBookingRow(UITestingSeed.bookingID))
    #expect(
        UITestingIdentifiers.timelineBookingRow(UITestingSeed.bookingID)
            != UITestingIdentifiers.bookingRow(UITestingSeed.bookingID)
    )
    #expect(
        UITestingIdentifiers.contentOpenBookingRow(UITestingSeed.openBookingID2)
            == UITestingIdentifiers.seededContentOpenBookingRow2
    )
    #expect(
        UITestingIdentifiers.contentOpenBookingRow(UITestingSeed.openBookingID2)
            != UITestingIdentifiers.bookingRow(UITestingSeed.openBookingID2)
    )
    #expect(UITestingIdentifiers.seededOpenBookingTitle2 == UITestingSeed.openBookingTitle2)
}
