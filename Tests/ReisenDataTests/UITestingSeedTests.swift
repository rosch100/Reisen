import Testing
import Foundation
import SwiftData
import ReisenData
import ReisenDomain

@MainActor
@Test func uiTestingSeed_insertsStableTripsBookingsOpenAndGap() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    try UITestingSeed.insertPopulated(into: container.mainContext)

    let trips = try container.mainContext.fetch(FetchDescriptor<SDTrip>())
    let bookings = try container.mainContext.fetch(FetchDescriptor<SDBooking>())
    let openBookings = bookings.filter { $0.trip == nil }.sorted { $0.startAt < $1.startAt }
    #expect(Set(trips.map(\.id)) == [UITestingSeed.tripID, UITestingSeed.tripID2])
    #expect(Set(bookings.map(\.id)) == [
        UITestingSeed.bookingID,
        UITestingSeed.bookingID2,
        UITestingSeed.openBookingID,
        UITestingSeed.openBookingID2,
        UITestingSeed.openBookingID3,
    ])
    #expect(bookings.first(where: { $0.id == UITestingSeed.bookingID })?.trip?.id == UITestingSeed.tripID)
    #expect(bookings.first(where: { $0.id == UITestingSeed.openBookingID })?.trip == nil)
    #expect(openBookings.map(\.startAt) == [
        UITestingSeed.firstBookingEnd.addingTimeInterval(3_600),
        UITestingSeed.firstBookingEnd.addingTimeInterval(10_800),
        UITestingSeed.firstBookingEnd.addingTimeInterval(18_000),
    ])
    #expect(openBookings.map { $0.endAt.timeIntervalSince($0.startAt) } == [3_600, 3_600, 3_600])

    let trip = try #require(trips.first(where: { $0.id == UITestingSeed.tripID }))
    for open in openBookings {
        #expect(OpenBookingMatching.isCandidate(open, for: trip))
    }

    let tripBookings = bookings
        .filter { $0.trip?.id == UITestingSeed.tripID }
        .map { DomainMapper.booking(from: $0) }
    let gaps = GapDetector().computeGaps(
        bookings: tripBookings,
        tripStart: UITestingSeed.firstBookingStart,
        tripEnd: UITestingSeed.secondBookingEnd
    )
    #expect(gaps.contains { $0.timelineItemID == UITestingSeed.seededGapTimelineItemID })

    let planned = AutoGapPlanner.plan(
        tripStart: UITestingSeed.firstBookingStart,
        tripEnd: UITestingSeed.secondBookingEnd,
        bookings: tripBookings
    )
    #expect(planned.isEmpty)

    try UITestingSeed.insertPopulated(into: container.mainContext)
    #expect(try container.mainContext.fetch(FetchDescriptor<SDTrip>()).count == 2)
    #expect(try container.mainContext.fetch(FetchDescriptor<SDBooking>()).count == 5)
}
