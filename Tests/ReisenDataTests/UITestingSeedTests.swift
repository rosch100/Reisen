import Testing
import Foundation
import SwiftData
import ReisenData
import ReisenDomain

@MainActor
@Test func uiTestingSeed_insertsStableTripsBookingsAndOpen() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    try UITestingSeed.insertPopulated(into: container.mainContext)

    let trips = try container.mainContext.fetch(FetchDescriptor<SDTrip>())
    let bookings = try container.mainContext.fetch(FetchDescriptor<SDBooking>())
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

    try UITestingSeed.insertPopulated(into: container.mainContext)
    #expect(try container.mainContext.fetch(FetchDescriptor<SDTrip>()).count == 2)
    #expect(try container.mainContext.fetch(FetchDescriptor<SDBooking>()).count == 5)
}
