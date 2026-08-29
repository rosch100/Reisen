import Testing
import Foundation
import SwiftData
import ReisenData
import ReisenDomain

@MainActor
private func makeContainer() throws -> ModelContainer {
    try PersistenceBootstrap.makeInMemoryContainer()
}

@MainActor
private func makeTrip(in context: ModelContext, title: String = "Italien") -> SDTrip {
    let trip = SDTrip(
        id: UUID(),
        title: title,
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date(timeIntervalSince1970: 1_700_200_000)
    )
    context.insert(trip)
    return trip
}

@MainActor
private func makeBooking(
    in context: ModelContext,
    provider: ProviderID,
    title: String,
    trip: SDTrip?
) -> SDBooking {
    let booking = SDBooking(
        id: UUID(),
        providerRaw: provider.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: title,
        startAt: Date(timeIntervalSince1970: 1_700_050_000),
        endAt: Date(timeIntervalSince1970: 1_700_140_000),
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: trip
    )
    context.insert(booking)
    return booking
}

@MainActor
@Test func tripDeletion_keepAsOpen_unlinksBookingsAndRemovesTrip() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let trip = makeTrip(in: context)
    let booking = makeBooking(in: context, provider: .check24, title: "Hotel Rom", trip: trip)
    try context.save()

    try TripDeletion.perform(trip: trip, in: context, bookings: .keepAsOpen)

    let trips = try context.fetch(FetchDescriptor<SDTrip>())
    let bookings = try context.fetch(FetchDescriptor<SDBooking>())
    #expect(trips.isEmpty)
    #expect(bookings.count == 1)
    #expect(bookings[0].id == booking.id)
    #expect(bookings[0].trip == nil)
}

@MainActor
@Test func tripDeletion_deleteContained_removesTripAndBookings() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let trip = makeTrip(in: context)
    let synced = makeBooking(in: context, provider: .check24, title: "Flug", trip: trip)
    let manual = makeBooking(in: context, provider: .manual, title: "Taxi", trip: trip)
    let deadline = SDCancellationDeadline(
        deadlineAt: Date(timeIntervalSince1970: 1_699_000_000),
        policyText: "free",
        booking: synced
    )
    context.insert(deadline)
    try context.save()
    let syncedID = synced.id
    let manualID = manual.id

    try TripDeletion.perform(trip: trip, in: context, bookings: .deleteContained)

    #expect(try context.fetch(FetchDescriptor<SDTrip>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<SDBooking>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<SDCancellationDeadline>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == syncedID })).isEmpty)
    #expect(try context.fetch(FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == manualID })).isEmpty)
}

@MainActor
@Test func tripDeletion_keepAsOpen_emptyTrip_deletesTrip() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let trip = makeTrip(in: context)
    try context.save()
    try TripDeletion.perform(trip: trip, in: context, bookings: .keepAsOpen)
    #expect(try context.fetch(FetchDescriptor<SDTrip>()).isEmpty)
}

@MainActor
@Test func bookingDeletion_removesBookingChildrenAndLeavesTrip() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let trip = makeTrip(in: context)
    let booking = makeBooking(in: context, provider: .opodo, title: "Hotel", trip: trip)
    let deadline = SDCancellationDeadline(
        deadlineAt: Date(timeIntervalSince1970: 1_699_000_000),
        policyText: "free",
        booking: booking
    )
    context.insert(deadline)
    try context.save()
    let bookingID = booking.id
    let tripID = trip.id

    try BookingDeletion.perform(booking: booking, in: context)

    #expect(try context.fetch(FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == bookingID })).isEmpty)
    #expect(try context.fetch(FetchDescriptor<SDCancellationDeadline>()).isEmpty)
    let trips = try context.fetch(FetchDescriptor<SDTrip>())
    #expect(trips.count == 1)
    #expect(trips[0].id == tripID)
    #expect(trips[0].resolvedBookings.isEmpty)
}
