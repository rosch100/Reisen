import Testing
import Foundation
import SwiftData
import ReisenData
import ReisenDomain

@MainActor
@Test func uiTestingSeed_insertsStableTripAndBooking() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    try UITestingSeed.insertPopulated(into: container.mainContext)

    let trips = try container.mainContext.fetch(FetchDescriptor<SDTrip>())
    let bookings = try container.mainContext.fetch(FetchDescriptor<SDBooking>())
    #expect(trips.map(\.id) == [UITestingSeed.tripID])
    #expect(bookings.map(\.id) == [UITestingSeed.bookingID])
    #expect(bookings[0].trip?.id == UITestingSeed.tripID)

    try UITestingSeed.insertPopulated(into: container.mainContext)
    #expect(try container.mainContext.fetch(FetchDescriptor<SDTrip>()).count == 1)
}
