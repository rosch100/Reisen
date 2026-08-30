import Foundation
import Testing
import ReisenDomain

private let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()

private let tripStart = Date(timeIntervalSince1970: 1_700_000_000)
private let tripEnd = tripStart.addingTimeInterval(7 * 86_400)
private let entryTripID = UUID()

@Test func tripBookingDateWindow_assignedTripID_nilEntryStaysOpen() {
    let assigned = TripBookingDateWindow.assignedTripID(
        entryTripID: nil,
        bookingStart: tripStart,
        bookingEnd: tripEnd,
        tripStart: tripStart,
        tripEnd: tripEnd,
        calendar: utcCalendar
    )
    #expect(assigned == nil)
}

@Test func tripBookingDateWindow_assignedTripID_inWindowKeepsEntryTrip() {
    let assigned = TripBookingDateWindow.assignedTripID(
        entryTripID: entryTripID,
        bookingStart: tripStart,
        bookingEnd: tripStart.addingTimeInterval(86_400),
        tripStart: tripStart,
        tripEnd: tripEnd,
        calendar: utcCalendar
    )
    #expect(assigned == entryTripID)
}

@Test func tripBookingDateWindow_assignedTripID_outsideWindowStaysOpen() {
    let bookingStart = tripEnd.addingTimeInterval(30 * 86_400)
    let assigned = TripBookingDateWindow.assignedTripID(
        entryTripID: entryTripID,
        bookingStart: bookingStart,
        bookingEnd: bookingStart.addingTimeInterval(86_400),
        tripStart: tripStart,
        tripEnd: tripEnd,
        calendar: utcCalendar
    )
    #expect(assigned == nil)
}

@Test func tripBookingDateWindow_assignedTripID_missingTripDatesStaysOpen() {
    let assigned = TripBookingDateWindow.assignedTripID(
        entryTripID: entryTripID,
        bookingStart: tripStart,
        bookingEnd: tripEnd,
        tripStart: nil,
        tripEnd: nil,
        calendar: utcCalendar
    )
    #expect(assigned == nil)
}
