import Testing
import Foundation
import ReisenDomain

@Test func leadTimesDays_fireAtSubtractsLeadDaysFromReferenceDate() {
    let calendar = Calendar(identifier: .gregorian)
    let reference = Date(timeIntervalSince1970: 1_700_000_000)
    let fireAt = LeadTimesDays.fireAt(referenceDate: reference, leadDays: 3, calendar: calendar)
    let expected = calendar.date(byAdding: .day, value: -3, to: reference)

    #expect(fireAt == expected)
}

@Test func leadTimesDays_normalizedSortsAndFiltersPositiveValues() {
    #expect(LeadTimesDays.normalized([3, 1, 0, -2, 3]) == [1, 3, 3])
}

@Test func preTravelDesiredItems_matchDesiredKeysForTrip() {
    let tripID = UUID()
    let otherTripID = UUID()
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    let booking = Booking(
        id: UUID(),
        provider: .check24,
        bookingType: .hotel,
        startAt: now.addingTimeInterval(60 * 60 * 24 * 10),
        endAt: now.addingTimeInterval(60 * 60 * 24 * 11),
        tripID: tripID,
        guestHints: [
            BookingGuestHint(
                title: "Handtücher",
                detail: "Selbst mitbringen",
                sourceKey: "test:towels"
            ),
        ]
    )
    let otherTripBooking = Booking(
        id: UUID(),
        provider: .check24,
        bookingType: .hotel,
        startAt: now.addingTimeInterval(60 * 60 * 24 * 10),
        endAt: now.addingTimeInterval(60 * 60 * 24 * 11),
        tripID: otherTripID,
        guestHints: booking.guestHints
    )
    let withoutHints = Booking(
        id: UUID(),
        provider: .check24,
        bookingType: .hotel,
        startAt: now.addingTimeInterval(60 * 60 * 24 * 10),
        endAt: now.addingTimeInterval(60 * 60 * 24 * 11),
        tripID: tripID
    )

    let desired = PreTravelHintKeying.desiredKeys(
        tripID: tripID,
        bookings: [booking, otherTripBooking, withoutHints],
        leadTimesDays: [7, 3],
        now: now,
        calendar: Calendar(identifier: .gregorian)
    )
    let items = PreTravelHintDesiredItems.itemsByKey(
        tripID: tripID,
        bookings: [booking, otherTripBooking, withoutHints],
        bookingTitles: [:],
        leadTimes: LeadTimesDays.normalized([7, 3]),
        now: now,
        calendar: Calendar(identifier: .gregorian)
    )

    #expect(desired.count == 2)
    #expect(desired.allSatisfy { $0.bookingID == booking.id })
    #expect(Set(items.keys) == desired)
}

@Test func preTravelUnwantedKeys_areDesiredSubtractedFromExisting() {
    let bookingID = UUID()
    let a = PreTravelHintKeying.LinkKey(bookingID: bookingID, leadDays: 1)
    let b = PreTravelHintKeying.LinkKey(bookingID: bookingID, leadDays: 2)
    let c = PreTravelHintKeying.LinkKey(bookingID: bookingID, leadDays: 3)

    let unwanted = PreTravelHintKeying.unwantedKeys(existing: [a, b, c], desired: [a, b])
    #expect(unwanted == [c])
}

@Test func bookingGuestHintPrepKeywords_matchLinenTowelsNotGenericBringOrFee() {
    #expect(!BookingGuestHintPrepKeywords.matches("Parkplatz gegen Aufpreis von 15 EUR."))
    #expect(!BookingGuestHintPrepKeywords.matches("Frühstück gegen Gebühr am Morgen."))
    #expect(!BookingGuestHintPrepKeywords.matches("Parking extra fee."))
    #expect(!BookingGuestHintPrepKeywords.matches("Schlüssel mitbringen."))
    #expect(BookingGuestHintPrepKeywords.matches("Handtücher gegen Aufpreis."))
    #expect(BookingGuestHintPrepKeywords.matches("Towels extra fee."))
    #expect(BookingGuestHintPrepKeywords.matches("Bettwäsche selbst mitbringen."))
}

@Test func bookingGuestHint_dedupedBySourceKey_keepsFirstOccurrence() {
    let hints = [
        BookingGuestHint(title: "A", detail: "1", sourceKey: "k1"),
        BookingGuestHint(title: "B", detail: "2", sourceKey: "k1"),
        BookingGuestHint(title: "C", detail: "3", sourceKey: "k2"),
    ]

    let deduped = BookingGuestHint.dedupedBySourceKey(hints)
    #expect(deduped.count == 2)
    #expect(deduped[0].title == "A")
    #expect(deduped[1].title == "C")
}

@Test func preTravelNotificationItems_matchNotificationDesiredKeys() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let booking = Booking(
        id: UUID(),
        provider: .check24,
        bookingType: .hotel,
        startAt: now.addingTimeInterval(60 * 60 * 24 * 10),
        endAt: now.addingTimeInterval(60 * 60 * 24 * 11),
        guestHints: [
            BookingGuestHint(
                title: "Handtücher",
                detail: "Selbst mitbringen",
                sourceKey: "test:towels"
            ),
        ]
    )
    let leadTimes = LeadTimesDays.normalized([7, 3])

    let items = PreTravelHintNotificationItems.items(
        bookings: [booking],
        bookingTitles: [:],
        leadTimes: leadTimes,
        now: now,
        calendar: Calendar(identifier: .gregorian)
    )
    let desired = PreTravelHintKeying.notificationDesiredKeys(
        bookings: [booking],
        bookingTitles: [:],
        leadTimes: leadTimes,
        now: now,
        calendar: Calendar(identifier: .gregorian)
    )

    #expect(items.count == 2)
    #expect(Set(items.map(\.notificationKey)) == desired)
}
