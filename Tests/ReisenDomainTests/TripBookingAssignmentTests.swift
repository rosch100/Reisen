import Foundation
import Testing
import ReisenDomain

private func booking(
    id: UUID = UUID(),
    bookingType: BookingType = .hotel,
    startAt: Date,
    endAt: Date,
    status: BookingStatus = .confirmed,
    tripID: UUID? = nil
) -> Booking {
    Booking(
        id: id,
        provider: .check24,
        bookingType: bookingType,
        startAt: startAt,
        endAt: endAt,
        status: status,
        tripID: tripID
    )
}

@Test func tripBookingAssignment_withoutRestriction_usesDateWindow() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let tripStart = now.addingTimeInterval(86_400)
    let tripEnd = tripStart.addingTimeInterval(86_400 * 5)
    let selectedID = UUID()
    let extraInWindowID = UUID()
    let outsideID = UUID()

    let trip = Trip(title: "T", startDate: tripStart, endDate: tripEnd)
    let ids = TripBookingAssignment().bookingIDsToAssign(
        bookings: [
            booking(id: selectedID, startAt: tripStart, endAt: tripStart.addingTimeInterval(86_400)),
            booking(id: extraInWindowID, startAt: tripStart.addingTimeInterval(86_400), endAt: tripStart.addingTimeInterval(172_800)),
            booking(
                id: outsideID,
                startAt: tripEnd.addingTimeInterval(86_400),
                endAt: tripEnd.addingTimeInterval(172_800)
            ),
        ],
        trip: trip,
        restrictingTo: nil,
        now: now,
        windowCalendar: calendar
    )

    #expect(Set(ids) == Set([selectedID, extraInWindowID]))
}

@Test func tripBookingAssignment_withRestriction_assignsOnlySelectedOpenBookings() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let tripStart = now.addingTimeInterval(86_400)
    let tripEnd = tripStart.addingTimeInterval(86_400 * 2)
    let selectedID = UUID()
    let extraInWindowID = UUID()
    let selectedOutsideWindowID = UUID()
    let cancelledSelectedID = UUID()

    let trip = Trip(title: "T", startDate: tripStart, endDate: tripEnd)
    let ids = TripBookingAssignment().bookingIDsToAssign(
        bookings: [
            booking(id: selectedID, startAt: tripStart, endAt: tripStart.addingTimeInterval(86_400)),
            booking(id: extraInWindowID, startAt: tripStart, endAt: tripStart.addingTimeInterval(86_400)),
            booking(
                id: selectedOutsideWindowID,
                startAt: tripEnd.addingTimeInterval(86_400),
                endAt: tripEnd.addingTimeInterval(172_800)
            ),
            booking(
                id: cancelledSelectedID,
                startAt: tripStart,
                endAt: tripStart.addingTimeInterval(86_400),
                status: .cancelled
            ),
        ],
        trip: trip,
        restrictingTo: [selectedID, selectedOutsideWindowID, cancelledSelectedID],
        now: now,
        windowCalendar: calendar
    )

    #expect(Set(ids) == Set([selectedID, selectedOutsideWindowID]))
}

@Test("TripBookingAssignment Default: Hotel-GMT-Anker nicht über Geräte-TZ verschieben")
func tripBookingAssignment_defaultCalendarKeepsHotelGMTDay() {
    // 2026-09-05 00:00 GMT — in America/Los_Angeles noch 4.9. abends.
    let stay = HotelStayDate.dateOnly(year: 2026, month: 9, day: 5)
    let tripEnd = HotelStayDate.dateOnly(year: 2026, month: 9, day: 10)
    let bookingEnd = HotelStayDate.dateOnly(year: 2026, month: 9, day: 7)
    let id = UUID()
    let trip = Trip(title: "T", startDate: stay, endDate: tripEnd)

    let ids = TripBookingAssignment().assignableBookingIDs(
        bookings: [booking(id: id, startAt: stay, endAt: bookingEnd)],
        trip: trip,
        now: stay
    )

    #expect(ids == [id])
    #expect(HotelStayDate.format(stay, dateFormat: "d.M.") == "5.9.")
}

@Test("TripBookingAssignment assignableCount Default: Hotel-GMT-Fenster")
func tripBookingAssignment_assignableCount_defaultCalendarKeepsHotelGMTDay() {
    let stay = HotelStayDate.dateOnly(year: 2026, month: 9, day: 5)
    let tripEnd = HotelStayDate.dateOnly(year: 2026, month: 9, day: 10)
    let bookingEnd = HotelStayDate.dateOnly(year: 2026, month: 9, day: 7)

    let count = TripBookingAssignment().assignableCount(
        bookings: [booking(startAt: stay, endAt: bookingEnd)],
        startDate: stay,
        endDate: tripEnd,
        now: stay
    )

    #expect(count == 1)
}

@Test("TripBookingAssignment: Flug upcoming typbewusst (East-of-GMT), Fenster bleibt GMT")
func tripBookingAssignment_flightUpcomingUsesListInclusionCalendarNotGMT() {
    // now = 2026-09-05 02:00 GMT → East (+10) = 5.9. 12:00.
    // Flugstart 4.9. 20:00 GMT = 5.9. 06:00 East → under GMT not upcoming, under East yes.
    var east = Calendar(identifier: .gregorian)
    east.timeZone = TimeZone(secondsFromGMT: 10 * 3600)!

    let now = HotelStayDate.dateOnly(year: 2026, month: 9, day: 5).addingTimeInterval(2 * 3600)
    let flightStart = HotelStayDate.dateOnly(year: 2026, month: 9, day: 4)
        .addingTimeInterval(20 * 3600)
    let flightEnd = flightStart.addingTimeInterval(3_600)
    let tripStart = HotelStayDate.dateOnly(year: 2026, month: 9, day: 1)
    let tripEnd = HotelStayDate.dateOnly(year: 2026, month: 9, day: 10)
    let id = UUID()
    let trip = Trip(title: "T", startDate: tripStart, endDate: tripEnd)
    let flight = booking(
        id: id,
        bookingType: .flight,
        startAt: flightStart,
        endAt: flightEnd
    )

    #expect(
        HotelStayDate.calendar.startOfDay(for: flightStart)
            < HotelStayDate.calendar.startOfDay(for: now)
    )
    #expect(east.startOfDay(for: flightStart) >= east.startOfDay(for: now))

    // Altes Einzel-Kalender-Verhalten (GMT auch für upcoming) → nicht assignable.
    #expect(
        TripBookingAssignment().assignableBookingIDs(
            bookings: [flight],
            trip: trip,
            now: now,
            upcomingCalendar: HotelStayDate.calendar
        ).isEmpty
    )

    // Typbewusst (Flug-ListInclusion = Gerätekalender; hier East-Override) → assignable.
    #expect(
        TripBookingAssignment().assignableBookingIDs(
            bookings: [flight],
            trip: trip,
            now: now,
            upcomingCalendar: east
        ) == [id]
    )

    // Default nil: Flug → listInclusionCalendar (== Calendar.current).
    #expect(
        TripBookingAssignment().assignableBookingIDs(
            bookings: [flight],
            trip: trip,
            now: now,
            upcomingCalendar: BookingType.flight.listInclusionCalendar
        )
            == TripBookingAssignment().assignableBookingIDs(
                bookings: [flight],
                trip: trip,
                now: now
            )
    )

    #expect(
        TripBookingAssignment().assignableCount(
            bookings: [flight],
            startDate: tripStart,
            endDate: tripEnd,
            now: now,
            upcomingCalendar: east
        ) == 1
    )
}
