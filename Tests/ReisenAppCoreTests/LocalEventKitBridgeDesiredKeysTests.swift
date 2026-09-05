import Foundation
import Testing
@testable import ReisenAppCore
import ReisenDomain

@MainActor
@Suite("LocalEventKitBridge offset eligibility")
struct LocalEventKitBridgeDesiredKeysTests {
    @Test("offset-less hotel drafts are excluded from sync eligibility so stale keys can clean up")
    func offsetLessHotelDraftsExcludedFromEligibility() {
        let bookingID = UUID()
        let tripID = UUID()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = Date(timeIntervalSince1970: 1_800_086_400)

        let hotelWithoutOffset = Booking(
            id: bookingID,
            provider: .opodo,
            bookingType: .hotel,
            title: "Hotel",
            startAt: start,
            endAt: end,
            hotelOffsetSeconds: nil,
            status: .confirmed,
            tripID: tripID
        )
        let hotelWithOffset = Booking(
            id: bookingID,
            provider: .opodo,
            bookingType: .hotel,
            title: "Hotel",
            startAt: start,
            endAt: end,
            hotelOffsetSeconds: 3600,
            status: .confirmed,
            tripID: tripID
        )
        let trip = Trip(
            id: tripID,
            title: "Trip",
            startDate: start,
            endDate: end,
            destination: "Somewhere",
            bookingIDs: [bookingID]
        )
        let draft = CalendarTimelineHotelDraftBuilder.draft(
            trip: trip,
            booking: hotelWithoutOffset,
            title: "Hotel"
        )

        let excluded = LocalEventKitBridge.calendarDraftsEligibleForSync(
            drafts: [draft],
            bookingsByID: [bookingID: hotelWithoutOffset]
        )
        #expect(excluded.isEmpty)

        let included = LocalEventKitBridge.calendarDraftsEligibleForSync(
            drafts: [draft],
            bookingsByID: [bookingID: hotelWithOffset]
        )
        #expect(included.count == 1)
        #expect(included[0].timeZone.secondsFromGMT() == 3600)
    }
}
