import Testing
import Foundation
import SwiftData
import ReisenData
import ReisenDomain

@MainActor
@Test func uiTestingSeed_insertsStableTripsBookingsAndOpen() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let earliestOpenBookingReference = Calendar.current.startOfDay(for: Date())
    try UITestingSeed.insertPopulated(into: container.mainContext)
    let latestOpenBookingReference = Calendar.current.startOfDay(for: Date())

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
    let firstOpenBooking = try #require(openBookings.first)
    #expect(firstOpenBooking.startAt >= earliestOpenBookingReference.addingTimeInterval(86_400 * 10))
    #expect(firstOpenBooking.startAt <= latestOpenBookingReference.addingTimeInterval(86_400 * 10))
    #expect(openBookings.map { $0.endAt.timeIntervalSince($0.startAt) } == [86_400, 86_400, 86_400])
    let openBookingOffsets = openBookings.dropFirst().map {
        $0.startAt.timeIntervalSince(firstOpenBooking.startAt)
    }
    #expect(openBookingOffsets == [172_800, 345_600])

    try UITestingSeed.insertPopulated(into: container.mainContext)
    #expect(try container.mainContext.fetch(FetchDescriptor<SDTrip>()).count == 2)
    #expect(try container.mainContext.fetch(FetchDescriptor<SDBooking>()).count == 5)
}
