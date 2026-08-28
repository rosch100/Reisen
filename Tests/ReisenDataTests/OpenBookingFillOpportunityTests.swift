import Foundation
import SwiftData
import Testing
import ReisenData
import ReisenDomain

private let day: TimeInterval = 24 * 60 * 60
private let hour: TimeInterval = 60 * 60

@MainActor
private func makeTrip(
    title: String,
    start: TimeInterval,
    end: TimeInterval,
    id: UUID = UUID()
) -> SDTrip {
    SDTrip(
        id: id,
        title: title,
        startDate: Date(timeIntervalSince1970: start),
        endDate: Date(timeIntervalSince1970: end)
    )
}

@MainActor
private func makeBooking(
    start: TimeInterval,
    end: TimeInterval,
    type: BookingType = .flight,
    trip: SDTrip? = nil,
    status: BookingStatus = .confirmed
) -> SDBooking {
    SDBooking(
        providerRaw: ProviderID.check24.rawValue,
        bookingTypeRaw: type.rawValue,
        title: "B",
        startAt: Date(timeIntervalSince1970: start),
        endAt: Date(timeIntervalSince1970: end),
        statusRaw: status.rawValue,
        trip: trip
    )
}

@MainActor
@Test func fillOpportunity_candidateWithInterGaps_returnsTrip() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext

    let trip = makeTrip(title: "Italien", start: 10 * day, end: 20 * day)
    let early = makeBooking(start: 10 * day, end: 10 * day + 3 * hour, trip: trip)
    let late = makeBooking(start: 18 * day, end: 18 * day + 3 * hour, trip: trip)
    trip.bookings = [early, late]

    let open = makeBooking(start: 14 * day, end: 15 * day)
    context.insert(trip)
    context.insert(early)
    context.insert(late)
    context.insert(open)
    try context.save()

    let now = Date(timeIntervalSince1970: 9 * day)
    let found = OpenBookingMatching.fillOpportunity(
        booking: open,
        trips: [trip],
        now: now
    )
    #expect(found?.id == trip.id)
    #expect(trip.completeness().hasTimeGaps)
}

@MainActor
@Test func fillOpportunity_onlyEdgeGaps_returnsNil() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext

    let trip = makeTrip(title: "NurRand", start: 10 * day, end: 20 * day)
    let hotel = makeBooking(
        start: 12 * day,
        end: 18 * day,
        type: .hotel,
        trip: trip
    )
    trip.bookings = [hotel]

    let open = makeBooking(start: 14 * day, end: 15 * day, type: .activity)
    context.insert(trip)
    context.insert(hotel)
    context.insert(open)
    try context.save()

    let now = Date(timeIntervalSince1970: 9 * day)
    #expect(trip.completeness().isTimelineComplete)
    #expect(trip.completeness().edgeGapCount >= 1)
    #expect(
        OpenBookingMatching.fillOpportunity(booking: open, trips: [trip], now: now) == nil
    )
}

@MainActor
@Test func fillOpportunity_outsideWindow_returnsNil() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext

    let trip = makeTrip(title: "Fenster", start: 10 * day, end: 15 * day)
    let early = makeBooking(start: 10 * day, end: 10 * day + 3 * hour, trip: trip)
    let late = makeBooking(start: 14 * day, end: 14 * day + 3 * hour, trip: trip)
    trip.bookings = [early, late]

    let open = makeBooking(start: 20 * day, end: 21 * day)
    context.insert(trip)
    context.insert(early)
    context.insert(late)
    context.insert(open)
    try context.save()

    let now = Date(timeIntervalSince1970: 9 * day)
    #expect(
        OpenBookingMatching.fillOpportunity(booking: open, trips: [trip], now: now) == nil
    )
}

@MainActor
@Test func fillOpportunity_twoTrips_picksEarlierStartDate() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext

    let later = makeTrip(title: "Später", start: 20 * day, end: 30 * day)
    let earlier = makeTrip(title: "Früher", start: 10 * day, end: 30 * day)

    func seedGapTrip(_ trip: SDTrip) -> (SDBooking, SDBooking) {
        let a = makeBooking(start: trip.startDate.timeIntervalSince1970, end: trip.startDate.timeIntervalSince1970 + 3 * hour, trip: trip)
        let b = makeBooking(start: trip.endDate.timeIntervalSince1970 - 3 * hour, end: trip.endDate.timeIntervalSince1970, trip: trip)
        trip.bookings = [a, b]
        return (a, b)
    }

    let (la, lb) = seedGapTrip(later)
    let (ea, eb) = seedGapTrip(earlier)
    let open = makeBooking(start: 22 * day, end: 23 * day)

    context.insert(later)
    context.insert(earlier)
    context.insert(la)
    context.insert(lb)
    context.insert(ea)
    context.insert(eb)
    context.insert(open)
    try context.save()

    let now = Date(timeIntervalSince1970: 9 * day)
    let found = OpenBookingMatching.fillOpportunity(
        booking: open,
        trips: [later, earlier],
        now: now
    )
    #expect(found?.id == earlier.id)
}

@MainActor
@Test func showsListGapBadge_hidesPastTrips() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext

    let trip = makeTrip(title: "Vergangen", start: 0, end: 5 * day)
    let early = makeBooking(start: 0, end: 3 * hour, trip: trip)
    let late = makeBooking(start: 4 * day, end: 4 * day + 3 * hour, trip: trip)
    trip.bookings = [early, late]
    context.insert(trip)
    context.insert(early)
    context.insert(late)
    try context.save()

    let now = Date(timeIntervalSince1970: 10 * day)
    #expect(trip.completeness().hasTimeGaps)
    #expect(trip.showsListGapBadge(now: now) == false)
    #expect(trip.listGapBadgeCount(now: now) == nil)

    let current = Date(timeIntervalSince1970: 2 * day)
    #expect(trip.showsListGapBadge(now: current))
    #expect(trip.listGapBadgeCount(now: current) == 1)
}

@MainActor
@Test func listGapBadgeCount_currentTripWithOnlyPastBookings_stillShowsGaps() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext

    // Reise endet in der Zukunft, Buchungen liegen aber schon in der Vergangenheit.
    let trip = makeTrip(title: "NurVergangenheit", start: 0, end: 20 * day)
    let early = makeBooking(start: 0, end: 3 * hour, trip: trip)
    let late = makeBooking(start: 4 * day, end: 4 * day + 3 * hour, trip: trip)
    trip.bookings = [early, late]
    context.insert(trip)
    context.insert(early)
    context.insert(late)
    try context.save()

    let now = Date(timeIntervalSince1970: 10 * day)
    #expect(trip.listGapBadgeCount(now: now) == 1)
}
