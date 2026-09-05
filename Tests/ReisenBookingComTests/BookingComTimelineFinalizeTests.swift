import Foundation
import Testing
@testable import ReisenBookingCom
import ReisenDomain

@MainActor
@Suite("BookingCom timeline finalize")
struct BookingComTimelineFinalizeTests {
    @Test("partial timelineFailures throw even when some bookings succeeded")
    func partialFailuresThrow() throws {
        let provider = BookingComTravelProvider()
        let draft = ProviderBookingDraft(
            provider: .booking,
            bookingType: .hotel,
            title: "Hotel",
            startAt: Date(timeIntervalSince1970: 1_800_000_000),
            endAt: Date(timeIntervalSince1970: 1_800_086_400),
            status: .confirmed
        )
        #expect(throws: (any Error).self) {
            try provider.finalizeTimelineCatalog(
                (
                    bookings: [draft],
                    timelineFailures: 1,
                    lastTimelineError: BookingComProviderError.catalogNotFound
                )
            )
        }
    }

    @Test("zero failures returns deduped bookings")
    func zeroFailuresReturnsBookings() throws {
        let provider = BookingComTravelProvider()
        let draft = ProviderBookingDraft(
            provider: .booking,
            bookingType: .hotel,
            title: "Hotel",
            externalUrl: "https://booking.com/x",
            startAt: Date(timeIntervalSince1970: 1_800_000_000),
            endAt: Date(timeIntervalSince1970: 1_800_086_400),
            status: .confirmed
        )
        let result = try provider.finalizeTimelineCatalog(
            (bookings: [draft, draft], timelineFailures: 0, lastTimelineError: nil)
        )
        #expect(result.count == 1)
    }
}
