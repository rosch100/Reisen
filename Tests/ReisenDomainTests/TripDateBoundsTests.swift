import Foundation
import Testing
import ReisenDomain

private func booking(
    id: UUID = UUID(),
    startAt: Date,
    endAt: Date
) -> Booking {
    Booking(
        id: id,
        provider: .check24,
        bookingType: .hotel,
        startAt: startAt,
        endAt: endAt,
        status: .confirmed
    )
}

@Test func tripDateBounds_emptyReturnsNil() {
    #expect(TripDateBounds.from(bookings: []) == nil)
}

@Test func tripDateBounds_singleBookingUsesCalendarDays() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let end = start.addingTimeInterval(86_400)
    let bounds = TripDateBounds.from(
        bookings: [booking(startAt: start, endAt: end)],
        calendar: calendar
    )

    #expect(bounds?.start == calendar.startOfDay(for: start))
    #expect(bounds?.end == calendar.startOfDay(for: end))
}

@Test func tripDateBounds_multipleBookingsUsesMinStartMaxEnd() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let earlyStart = Date(timeIntervalSince1970: 1_700_000_000)
    let lateEnd = Date(timeIntervalSince1970: 1_800_000_000)
    let middle = booking(
        startAt: earlyStart.addingTimeInterval(86_400),
        endAt: earlyStart.addingTimeInterval(172_800)
    )
    let early = booking(startAt: earlyStart, endAt: earlyStart.addingTimeInterval(43_200))
    let late = booking(startAt: lateEnd.addingTimeInterval(-86_400), endAt: lateEnd)

    let bounds = TripDateBounds.from(bookings: [middle, late, early], calendar: calendar)

    #expect(bounds?.start == calendar.startOfDay(for: earlyStart))
    #expect(bounds?.end == calendar.startOfDay(for: lateEnd))
}

@Test func tripDateBounds_formattedAbbreviatedRange() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let end = start.addingTimeInterval(86_400)
    let text = TripDateBounds.formattedAbbreviatedRange(
        from: [booking(startAt: start, endAt: end)],
        calendar: calendar
    )

    #expect(text != nil)
    #expect(text?.contains("–") == true)
}
