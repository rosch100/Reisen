import Testing
import Foundation
import ReisenDomain

@Test func desiredKeys_areScopedToTrip_andOnlyFreeCancellations_withFutureFireAt() {
    let tripID = UUID()
    let otherTripID = UUID()

    let bookingID = UUID()
    let otherBookingID = UUID()

    let now = Date(timeIntervalSince1970: 1_700_000_000)

    let booking = Booking(
        id: bookingID,
        provider: .check24,
        bookingType: .hotel,
        startAt: now.addingTimeInterval(60 * 60),
        endAt: now.addingTimeInterval(60 * 60 * 2),
        tripID: tripID
    )
    let otherBooking = Booking(
        id: otherBookingID,
        provider: .check24,
        bookingType: .hotel,
        startAt: now.addingTimeInterval(60 * 60),
        endAt: now.addingTimeInterval(60 * 60 * 2),
        tripID: otherTripID
    )

    let deadlines: [CancellationDeadline] = [
        .init(
            id: UUID(),
            deadlineAt: now.addingTimeInterval(60 * 60 * 24 * 10),
            isFreeCancellation: true,
            bookingID: bookingID
        ),
        .init(
            id: UUID(),
            deadlineAt: now.addingTimeInterval(60 * 60 * 24 * 10),
            isFreeCancellation: true,
            bookingID: otherBookingID
        ),
        .init(
            id: UUID(),
            deadlineAt: now.addingTimeInterval(60 * 60 * 24 * 10),
            isFreeCancellation: false,
            bookingID: bookingID
        )
    ]

    let desired = CancellationDeadlineKeying.desiredKeys(
        tripID: tripID,
        deadlines: deadlines,
        bookingsByID: [bookingID: booking, otherBookingID: otherBooking],
        leadTimesDays: [7, 3],
        now: now,
        calendar: Calendar(identifier: .gregorian)
    )

    // For the first deadline: fireAt = deadlineAt - leadDays.
    // - leadDays 7 => now + 3 days
    // - leadDays 3 => now + 7 days
    #expect(desired.count == 2)
}

@Test func unwantedKeys_are_desired_subtracted_from_existing() {
    let a = CancellationDeadlineKeying.LinkKey(cancellationDeadlineID: UUID(), leadDays: 1)
    let b = CancellationDeadlineKeying.LinkKey(cancellationDeadlineID: UUID(), leadDays: 2)
    let c = CancellationDeadlineKeying.LinkKey(cancellationDeadlineID: UUID(), leadDays: 3)

    let existing: Set<CancellationDeadlineKeying.LinkKey> = [a, b, c]
    let desired: Set<CancellationDeadlineKeying.LinkKey> = [a, b]

    let unwanted = CancellationDeadlineKeying.unwantedKeys(existing: existing, desired: desired)
    #expect(unwanted == [c])
}

