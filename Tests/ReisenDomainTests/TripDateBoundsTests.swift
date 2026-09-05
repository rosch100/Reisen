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

@Test("TripDateBounds Default: Hotel-GMT-Anker nicht über Geräte-TZ verschieben")
func tripDateBounds_defaultCalendarKeepsHotelGMTDay() {
    // 2026-09-05 00:00 GMT — in America/Los_Angeles noch 4.9. abends.
    let stay = HotelStayDate.dateOnly(year: 2026, month: 9, day: 5)
    let bounds = TripDateBounds.from(bookings: [booking(startAt: stay, endAt: stay)])
    #expect(bounds?.start == stay)
    #expect(HotelStayDate.format(bounds!.start, dateFormat: "d.M.") == "5.9.")
}

@Test("TripBookingDateWindow Default: Hotel-GMT bleibt im Fenster trotz westlicher Geräte-TZ-Semantik")
func tripBookingDateWindow_defaultCalendarHotelGMTInWindow() {
    let tripStart = HotelStayDate.dateOnly(year: 2026, month: 9, day: 1)
    let tripEnd = HotelStayDate.dateOnly(year: 2026, month: 9, day: 10)
    let bookingStart = HotelStayDate.dateOnly(year: 2026, month: 9, day: 5)
    let bookingEnd = HotelStayDate.dateOnly(year: 2026, month: 9, day: 7)
    #expect(
        TripBookingDateWindow.contains(
            bookingStart: bookingStart,
            bookingEnd: bookingEnd,
            tripStart: tripStart,
            tripEnd: tripEnd
        )
    )
}

