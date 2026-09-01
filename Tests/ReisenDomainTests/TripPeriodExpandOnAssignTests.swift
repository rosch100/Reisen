import Foundation
import Testing
import ReisenDomain

private let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()

/// South-Jakarta-ähnlich: Trip 2.9.–8.9., Buchung 8.8.
private let tripStart = Date(timeIntervalSince1970: 1_788_307_200) // 2026-09-02 00:00 UTC
private let tripEnd = Date(timeIntervalSince1970: 1_788_825_600) // 2026-09-08 00:00 UTC
private let outsideStart = Date(timeIntervalSince1970: 1_786_060_800) // 2026-08-08 00:00 UTC
private let outsideEnd = Date(timeIntervalSince1970: 1_786_082_400) // 2026-08-08 06:00 UTC

@Test func tripPeriodExpandOnAssign_inWindow_returnsNil() {
    let proposal = TripPeriodExpandOnAssign.proposalIfNeeded(
        bookingStart: tripStart.addingTimeInterval(86_400),
        bookingEnd: tripStart.addingTimeInterval(2 * 86_400),
        tripStart: tripStart,
        tripEnd: tripEnd,
        calendar: utcCalendar
    )
    #expect(proposal == nil)
}

@Test func tripPeriodExpandOnAssign_outsideWindow_proposesCalendarDayUnion() {
    let proposal = TripPeriodExpandOnAssign.proposalIfNeeded(
        bookingStart: outsideStart.addingTimeInterval(7 * 3600 + 45 * 60),
        bookingEnd: outsideEnd,
        tripStart: tripStart,
        tripEnd: tripEnd,
        calendar: utcCalendar
    )
    #expect(proposal != nil)
    #expect(proposal?.start == utcCalendar.startOfDay(for: outsideStart))
    #expect(proposal?.end == utcCalendar.startOfDay(for: tripEnd))
}

@Test func tripPeriodExpandOnAssign_bookingAfterTrip_extendsEnd() {
    let afterStart = tripEnd.addingTimeInterval(2 * 86_400)
    let afterEnd = afterStart.addingTimeInterval(86_400)
    let proposal = TripPeriodExpandOnAssign.proposalIfNeeded(
        bookingStart: afterStart,
        bookingEnd: afterEnd,
        tripStart: tripStart,
        tripEnd: tripEnd,
        calendar: utcCalendar
    )
    #expect(proposal?.start == utcCalendar.startOfDay(for: tripStart))
    #expect(proposal?.end == utcCalendar.startOfDay(for: afterEnd))
}

@Test func tripPeriodExpandOnAssign_multipleBookings_unionsAllOutside() {
    let midOutside = Date(timeIntervalSince1970: 1_787_356_800) // 2026-08-23
    let proposal = TripPeriodExpandOnAssign.proposalIfNeeded(
        bookings: [
            (outsideStart, outsideEnd),
            (midOutside, midOutside.addingTimeInterval(86_400)),
            (tripStart, tripStart.addingTimeInterval(86_400)),
        ],
        tripStart: tripStart,
        tripEnd: tripEnd,
        calendar: utcCalendar
    )
    #expect(proposal?.start == utcCalendar.startOfDay(for: outsideStart))
    #expect(proposal?.end == utcCalendar.startOfDay(for: tripEnd))
}

@Test func tripPeriodExpandOnAssign_allInWindow_multipleReturnsNil() {
    let proposal = TripPeriodExpandOnAssign.proposalIfNeeded(
        bookings: [
            (tripStart, tripStart.addingTimeInterval(86_400)),
            (tripEnd.addingTimeInterval(-86_400), tripEnd),
        ],
        tripStart: tripStart,
        tripEnd: tripEnd,
        calendar: utcCalendar
    )
    #expect(proposal == nil)
}
