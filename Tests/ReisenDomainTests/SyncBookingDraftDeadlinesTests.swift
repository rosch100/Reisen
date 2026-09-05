import Foundation
import Testing
import ReisenDomain

@Suite("SyncBookingDraftDeadlines")
struct SyncBookingDraftDeadlinesTests {
    @Test("non-empty draft replaces existing deadlines and wires bookingID")
    func nonEmptyDraftReplacesDeadlines() {
        let bookingID = UUID()
        var booking = Booking(
            id: bookingID,
            provider: .opodo,
            bookingType: .hotel,
            title: "Hotel",
            startAt: Date(timeIntervalSince1970: 1_700_000_000),
            endAt: Date(timeIntervalSince1970: 1_700_086_400),
            status: .confirmed
        )
        let staleID = UUID()
        booking.cancellationDeadlines = [
            CancellationDeadline(
                id: staleID,
                deadlineAt: Date(timeIntervalSince1970: 1_690_000_000),
                isStrict: true,
                isFreeCancellation: true,
                bookingID: bookingID
            )
        ]

        let freshID = UUID()
        let draft = ProviderBookingDraft(
            provider: .opodo,
            bookingType: .hotel,
            title: "Hotel",
            startAt: booking.startAt,
            endAt: booking.endAt,
            status: .confirmed,
            deadlines: [
                CancellationDeadline(
                    id: freshID,
                    deadlineAt: Date(timeIntervalSince1970: 1_699_000_000),
                    isStrict: false,
                    isFreeCancellation: true
                )
            ]
        )

        let added = SyncBookingDraftDeadlines.apply(from: draft, onto: &booking)
        #expect(added == 1)
        #expect(booking.cancellationDeadlines.map(\.id) == [freshID])
        #expect(booking.cancellationDeadlines.first?.bookingID == bookingID)
    }

    @Test("empty draft retains existing deadlines")
    func emptyDraftRetainsDeadlines() {
        let bookingID = UUID()
        let existingID = UUID()
        var booking = Booking(
            id: bookingID,
            provider: .opodo,
            bookingType: .hotel,
            title: "Hotel",
            startAt: Date(timeIntervalSince1970: 1_700_000_000),
            endAt: Date(timeIntervalSince1970: 1_700_086_400),
            status: .confirmed,
            cancellationDeadlines: [
                CancellationDeadline(
                    id: existingID,
                    deadlineAt: Date(timeIntervalSince1970: 1_699_000_000),
                    isStrict: true,
                    isFreeCancellation: true,
                    bookingID: bookingID
                )
            ]
        )

        let draft = ProviderBookingDraft(
            provider: .opodo,
            bookingType: .hotel,
            title: "Hotel",
            startAt: booking.startAt,
            endAt: booking.endAt,
            status: .confirmed,
            deadlines: []
        )

        let added = SyncBookingDraftDeadlines.apply(from: draft, onto: &booking)
        #expect(added == 0)
        #expect(booking.cancellationDeadlines.map(\.id) == [existingID])
    }
}
