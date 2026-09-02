import Testing
import Foundation
import ReisenData
import ReisenDomain
import ReisenSharedUI

private func sampleBooking() -> SDBooking {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    return SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Alt",
        startAt: start,
        endAt: start.addingTimeInterval(86_400),
        statusRaw: BookingStatus.confirmed.rawValue
    )
}

@Test func bookingCreateDraftSelection_replacesPriorTimelineSelection() {
    var selectedTimelineID: String? = "existing-booking-uuid"
    BookingCreateDraftSelection.selectCreateDraft(into: &selectedTimelineID)
    #expect(selectedTimelineID == BookingCreateDraftSelection.timelineID)
    #expect(BookingCreateDraftSelection.isCreateDraft(selectedTimelineID))
    #expect(selectedTimelineID != "existing-booking-uuid")
}

@Test func tripTimelineItem_displayItems_prependsCreateDraftWhenCreating() {
    let booking = sampleBooking()
    let withDraft = TripTimelineItem.displayItems(
        bookings: [booking],
        gaps: [],
        includesCreateDraft: true
    )
    #expect(withDraft.count == 2)
    #expect(withDraft.first?.id == BookingCreateDraftSelection.timelineID)
    guard case .createDraft = withDraft.first else {
        Issue.record("erste Zeile muss Create-Draft sein")
        return
    }
    guard case .booking(let shown) = withDraft[1] else {
        Issue.record("zweite Zeile muss bestehende Buchung sein")
        return
    }
    #expect(shown.id == booking.id)

    let withoutDraft = TripTimelineItem.displayItems(
        bookings: [booking],
        gaps: [],
        includesCreateDraft: false
    )
    #expect(withoutDraft.count == 1)
    #expect(withoutDraft.contains { BookingCreateDraftSelection.isCreateDraft($0.id) } == false)
}

@Test func uiTestingIdentifiers_bookingCreateDraftSurfaces_areStableAndDistinct() {
    #expect(UITestingIdentifiers.bookingCreateDraftTimeline == "reisen.booking.create-draft.timeline")
    #expect(UITestingIdentifiers.bookingCreateDraftSidebar == "reisen.booking.create-draft.sidebar")
    #expect(
        UITestingIdentifiers.bookingCreateDraftTimeline
            != UITestingIdentifiers.bookingCreateDraftSidebar
    )
    #expect(
        UITestingIdentifiers.bookingCreateDraftTimeline
            != BookingCreateDraftSelection.timelineID
    )
}
