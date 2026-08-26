import Foundation
import Testing
import ReisenDomain

private func span(
    id: UUID = UUID(),
    start: Date,
    end: Date,
    place: String
) -> BookingDaySpan {
    BookingDaySpan(id: id, startAt: start, endAt: end, placeKey: place)
}

@Test func bookingDayOverlap_adjacentSameDayDepartureArrival_doesNotOverlap() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let day1 = cal.date(from: DateComponents(year: 2026, month: 8, day: 1))!
    let day2 = cal.date(from: DateComponents(year: 2026, month: 8, day: 2))!
    let day3 = cal.date(from: DateComponents(year: 2026, month: 8, day: 3))!

    let a = span(start: day1, end: day2, place: "SIN")
    let b = span(start: day2, end: day3, place: "BKK")
    #expect(BookingDayOverlap.dayRangesOverlap(a, b, calendar: cal) == false)
    #expect(BookingDayOverlap.countsByID([a, b], calendar: cal).isEmpty)
}

@Test func bookingDayOverlap_overlappingRanges_countsBoth() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let d1 = cal.date(from: DateComponents(year: 2026, month: 8, day: 1))!
    let d3 = cal.date(from: DateComponents(year: 2026, month: 8, day: 3))!
    let d2 = cal.date(from: DateComponents(year: 2026, month: 8, day: 2))!
    let d4 = cal.date(from: DateComponents(year: 2026, month: 8, day: 4))!

    let a = span(start: d1, end: d3, place: "A")
    let b = span(start: d2, end: d4, place: "B")
    let counts = BookingDayOverlap.countsByID([a, b], calendar: cal)
    #expect(counts[a.id] == 1)
    #expect(counts[b.id] == 1)
}

@Test func bookingDayOverlap_samePlaceAndDates_notCountedAsOverlap() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let d1 = cal.date(from: DateComponents(year: 2026, month: 8, day: 1))!
    let d3 = cal.date(from: DateComponents(year: 2026, month: 8, day: 3))!

    let a = span(start: d1, end: d3, place: "Hotel")
    let b = span(start: d1, end: d3, place: "Hotel")
    #expect(BookingDayOverlap.isSamePlaceAndDates(a, b, calendar: cal))
    #expect(BookingDayOverlap.countsByID([a, b], calendar: cal).isEmpty)
}
