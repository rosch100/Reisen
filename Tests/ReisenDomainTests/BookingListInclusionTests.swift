import Foundation
import Testing
import ReisenDomain

private let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()

private let now = Date(timeIntervalSince1970: 1_700_000_000)
private let day: TimeInterval = 24 * 60 * 60

@Test func bookingListInclusion_isUpcomingOnOrAfterToday() {
    #expect(
        BookingListInclusion.isUpcoming(
            startAt: now,
            now: now,
            calendar: utcCalendar
        )
    )
    #expect(
        BookingListInclusion.isUpcoming(
            startAt: now.addingTimeInterval(day),
            now: now,
            calendar: utcCalendar
        )
    )
    #expect(
        !BookingListInclusion.isUpcoming(
            startAt: now.addingTimeInterval(-day),
            now: now,
            calendar: utcCalendar
        )
    )
}

@Test func bookingListInclusion_upcomingAlwaysListed() {
    #expect(
        BookingListInclusion.appearsInList(
            startAt: now.addingTimeInterval(day),
            status: .confirmed,
            provider: .check24,
            now: now,
            calendar: utcCalendar
        )
    )
}

@Test func bookingListInclusion_pastManualListedSyncedHidden() {
    let start = now.addingTimeInterval(-day)
    #expect(
        BookingListInclusion.appearsInList(
            startAt: start,
            status: .confirmed,
            provider: .manual,
            now: now,
            calendar: utcCalendar
        )
    )
    #expect(
        !BookingListInclusion.appearsInList(
            startAt: start,
            status: .confirmed,
            provider: .getYourGuide,
            now: now,
            calendar: utcCalendar
        )
    )
}

@Test func bookingListInclusion_cancelledNeverListed() {
    #expect(
        !BookingListInclusion.appearsInList(
            startAt: now.addingTimeInterval(day),
            status: .cancelled,
            provider: .manual,
            now: now,
            calendar: utcCalendar
        )
    )
}

@Test func bookingListInclusion_elapsedWhenEndBeforeToday() {
    let yesterday = now.addingTimeInterval(-day)
    let tomorrow = now.addingTimeInterval(day)
    #expect(BookingListInclusion.isElapsed(endAt: yesterday, now: now, calendar: utcCalendar))
    #expect(!BookingListInclusion.isElapsed(endAt: now, now: now, calendar: utcCalendar))
    #expect(!BookingListInclusion.isElapsed(endAt: tomorrow, now: now, calendar: utcCalendar))
}
