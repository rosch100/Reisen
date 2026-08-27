import Foundation
import Testing
import ReisenDomain

private func booking(
    id: UUID = UUID(),
    startAt: Date,
    endAt: Date,
    status: BookingStatus = .confirmed,
    tripID: UUID? = nil
) -> Booking {
    Booking(
        id: id,
        provider: .check24,
        bookingType: .hotel,
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
        calendar: calendar
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
        calendar: calendar
    )

    #expect(Set(ids) == Set([selectedID, selectedOutsideWindowID]))
}
