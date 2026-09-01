import Foundation
import SwiftData
import Testing
import ReisenData
import ReisenDomain

private let day: TimeInterval = 24 * 60 * 60
private let hour: TimeInterval = 60 * 60
private let now = Date(timeIntervalSince1970: 10 * day)
private let pastSyncedAt: TimeInterval = day
private let pastManualAt: TimeInterval = 2 * day
private let upcomingAt: TimeInterval = 20 * day

@MainActor
private func makeTrip() -> SDTrip {
    SDTrip(
        title: "T",
        startDate: Date(timeIntervalSince1970: 0),
        endDate: Date(timeIntervalSince1970: 30 * day)
    )
}

@MainActor
private func makeBooking(
    start: TimeInterval,
    duration: TimeInterval = hour,
    provider: ProviderID,
    trip: SDTrip? = nil,
    status: BookingStatus = .confirmed
) -> SDBooking {
    SDBooking(
        providerRaw: provider.rawValue,
        bookingTypeRaw: BookingType.activity.rawValue,
        title: "Tour",
        startAt: Date(timeIntervalSince1970: start),
        endAt: Date(timeIntervalSince1970: start + duration),
        statusRaw: status.rawValue,
        trip: trip
    )
}

@MainActor
private func persist(
    _ context: ModelContext,
    trip: SDTrip,
    _ bookings: SDBooking...
) throws {
    context.insert(trip)
    for booking in bookings {
        context.insert(booking)
    }
    try context.save()
}

@MainActor
@Test func sidebarOutlineBookings_current_matchesTimelineBookings() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let trip = makeTrip()
    let pastManual = makeBooking(start: pastManualAt, provider: .manual, trip: trip)
    let pastSynced = makeBooking(start: pastSyncedAt, provider: .getYourGuide, trip: trip)
    let upcoming = makeBooking(start: upcomingAt, provider: .check24, trip: trip)
    trip.bookings = [pastManual, pastSynced, upcoming]
    try persist(container.mainContext, trip: trip, pastManual, pastSynced, upcoming)

    let outline = trip.sidebarOutlineBookings(isElapsed: false, now: now)
    let timeline = trip.timelineBookings(now: now)
    #expect(outline.map(\.id) == timeline.map(\.id))
}

@MainActor
@Test func sidebarOutlineBookings_elapsed_includesPastProviderBookings() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let trip = makeTrip()
    let pastSynced = makeBooking(start: pastSyncedAt, provider: .getYourGuide, trip: trip)
    trip.bookings = [pastSynced]
    try persist(container.mainContext, trip: trip, pastSynced)

    #expect(trip.timelineBookings(now: now).isEmpty)

    let outline = trip.sidebarOutlineBookings(isElapsed: true, now: now)
    #expect(outline.map(\.id) == [pastSynced.id])
}

@MainActor
@Test func sidebarOutlineBookings_elapsed_excludesCancelledAndSortsByStartAt() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let trip = makeTrip()
    let later = makeBooking(start: pastManualAt, provider: .getYourGuide, trip: trip)
    let earlier = makeBooking(start: pastSyncedAt, provider: .check24, trip: trip)
    let cancelled = makeBooking(
        start: upcomingAt,
        provider: .manual,
        trip: trip,
        status: .cancelled
    )
    trip.bookings = [later, earlier, cancelled]
    try persist(container.mainContext, trip: trip, later, earlier, cancelled)

    let outline = trip.sidebarOutlineBookings(isElapsed: true, now: now)
    #expect(outline.map(\.id) == [earlier.id, later.id])
}
