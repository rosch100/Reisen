import Foundation
import Testing
import ReisenData
import ReisenDomain
import ReisenSharedUI

private let day: TimeInterval = 24 * 60 * 60
private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()
private let now = Date(timeIntervalSince1970: 1_700_000_000)

private func booking(endAt: Date) -> SDBooking {
    SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.activity.rawValue,
        title: "Tour",
        startAt: endAt.addingTimeInterval(-day),
        endAt: endAt,
        statusRaw: BookingStatus.confirmed.rawValue
    )
}

@Test func bookingElapsedText_nilWhenEndOnOrAfterToday() {
    #expect(BookingElapsedText.string(for: booking(endAt: now), now: now, calendar: utc) == nil)
    #expect(
        BookingElapsedText.string(
            for: booking(endAt: now.addingTimeInterval(day)),
            now: now,
            calendar: utc
        ) == nil
    )
}

@Test func bookingElapsedText_captionWhenEndBeforeToday() {
    let text = BookingElapsedText.string(
        for: booking(endAt: now.addingTimeInterval(-day)),
        now: now,
        calendar: utc
    )
    #expect(text == L10n.string(.bookingElapsed))
}

@Test("Hotel BookingElapsedText Default = HotelStayDate.calendar (West-of-GMT)")
func bookingElapsedText_hotelDefaultIgnoresDeviceWestOfGMT() {
    let end = HotelStayDate.dateOnly(year: 2026, month: 9, day: 5)
    let hotel = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Hotel",
        startAt: HotelStayDate.dateOnly(year: 2026, month: 9, day: 1),
        endAt: end,
        statusRaw: BookingStatus.confirmed.rawValue
    )
    let noon = end.addingTimeInterval(12 * 3600)
    #expect(BookingElapsedText.string(for: hotel, now: noon) == nil)

    var west = Calendar(identifier: .gregorian)
    west.timeZone = TimeZone(secondsFromGMT: -8 * 3600)!
    #expect(
        BookingElapsedText.string(for: hotel, now: noon, calendar: west)
            == L10n.string(.bookingElapsed)
    )
}

@Test func calendarDayTimelineSchedule_startsWithNowThenNextMidnights() {
    let dates = CalendarDayTimelineSchedule(calendar: utc).entries(from: now, mode: .normal)
    #expect(dates.first == now)
    #expect(dates.count > 2)
    let firstMidnight = utc.startOfDay(for: now)
    guard let nextMidnight = utc.date(byAdding: .day, value: 1, to: firstMidnight) else {
        Issue.record("next midnight")
        return
    }
    #expect(dates.contains(nextMidnight))
}
