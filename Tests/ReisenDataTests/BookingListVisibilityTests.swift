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
    trip: SDTrip? = nil,
    _ bookings: SDBooking...
) throws {
    if let trip {
        context.insert(trip)
    }
    for booking in bookings {
        context.insert(booking)
    }
    try context.save()
}

@MainActor
@Test func timelineBookings_keepsPastManualImport() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let trip = makeTrip()
    let pastManual = makeBooking(start: pastManualAt, provider: .manual, trip: trip)
    let pastSynced = makeBooking(start: pastSyncedAt, provider: .getYourGuide, trip: trip)
    let upcoming = makeBooking(start: upcomingAt, provider: .check24, trip: trip)
    trip.bookings = [pastManual, pastSynced, upcoming]
    try persist(container.mainContext, trip: trip, pastManual, pastSynced, upcoming)

    let listed = trip.timelineBookings(now: now)
    #expect(Set(listed.map(\.id)) == Set([pastManual.id, upcoming.id]))
}

@MainActor
@Test func listedUnassigned_keepsPastManualImport() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let pastManual = makeBooking(start: pastManualAt, provider: .manual)
    let pastSynced = makeBooking(start: pastSyncedAt, provider: .getYourGuide)
    let upcoming = makeBooking(start: upcomingAt, provider: .manual)
    try persist(container.mainContext, pastManual, pastSynced, upcoming)

    let listed = OpenBookingMatching.listedUnassigned(
        in: [pastManual, pastSynced, upcoming],
        now: now
    )
    #expect(Set(listed.map(\.id)) == Set([pastManual.id, upcoming.id]))
}

@MainActor
@Test func openUnassigned_excludesPastManualImport() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let pastManual = makeBooking(start: pastManualAt, provider: .manual)
    let upcoming = makeBooking(start: upcomingAt, provider: .manual)
    try persist(container.mainContext, pastManual, upcoming)

    let open = OpenBookingMatching.openUnassigned(in: [pastManual, upcoming], now: now)
    #expect(open.map(\.id) == [upcoming.id])
}

@MainActor
@Test func currentUnassigned_excludesElapsedManual() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let pastManual = makeBooking(start: pastManualAt, provider: .manual)
    let upcoming = makeBooking(start: upcomingAt, provider: .manual)
    try persist(container.mainContext, pastManual, upcoming)

    let current = OpenBookingMatching.currentUnassigned(
        in: [pastManual, upcoming],
        now: now
    )
    #expect(current.map(\.id) == [upcoming.id])
}

@MainActor
@Test func unassignedList_pastEnd_selectsElapsedMailbox() {
    let pastEnd = Date(timeIntervalSince1970: pastManualAt)
    let upcomingEnd = Date(timeIntervalSince1970: upcomingAt)
    #expect(OpenBookingMatching.unassignedList(endAt: pastEnd, now: now) == .elapsed)
    #expect(OpenBookingMatching.unassignedList(endAt: upcomingEnd, now: now) == .current)
}

@MainActor
@Test func elapsedUnassigned_keepsPastManualImport() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let pastManual = makeBooking(start: pastManualAt, provider: .manual)
    let upcoming = makeBooking(start: upcomingAt, provider: .manual)
    try persist(container.mainContext, pastManual, upcoming)

    let elapsed = OpenBookingMatching.elapsedUnassigned(
        in: [pastManual, upcoming],
        now: now
    )
    #expect(elapsed.map(\.id) == [pastManual.id])
}

@MainActor
@Test func trip_isElapsedWhenEndBeforeToday() {
    let trip = SDTrip(
        title: "P",
        startDate: Date(timeIntervalSince1970: 0),
        endDate: Date(timeIntervalSince1970: pastManualAt)
    )
    #expect(trip.isElapsed(now: now))
    let current = SDTrip(
        title: "C",
        startDate: Date(timeIntervalSince1970: upcomingAt),
        endDate: Date(timeIntervalSince1970: upcomingAt + day)
    )
    #expect(!current.isElapsed(now: now))
}

@MainActor
@Test func fillOpportunity_pastManualDoesNotFillGappyTrip() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let trip = makeTrip()
    let early = makeBooking(start: 0, provider: .check24, trip: trip)
    let late = makeBooking(start: 4 * day, provider: .check24, trip: trip)
    trip.bookings = [early, late]
    let pastManual = makeBooking(start: pastManualAt, provider: .manual)
    try persist(container.mainContext, trip: trip, early, late, pastManual)

    #expect(trip.completeness().hasTimeGaps)
    #expect(
        OpenBookingMatching.fillOpportunity(booking: pastManual, trips: [trip], now: now) == nil
    )
}

@MainActor
@Test func partitionByFillOpportunity_pastManualStaysInOther() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let pastManual = makeBooking(start: pastManualAt, provider: .manual)
    let upcoming = makeBooking(start: upcomingAt, provider: .manual)
    try persist(container.mainContext, pastManual, upcoming)

    let partition = OpenBookingMatching.partitionByFillOpportunity(
        bookings: [pastManual, upcoming],
        trips: [],
        now: now
    )
    #expect(partition.fillable.isEmpty)
    #expect(Set(partition.other.map(\.id)) == Set([pastManual.id, upcoming.id]))
}

@MainActor
@Test func timelineBookings_hidesCancelledPastManual() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let trip = makeTrip()
    let cancelled = makeBooking(
        start: pastManualAt,
        provider: .manual,
        trip: trip,
        status: .cancelled
    )
    trip.bookings = [cancelled]
    try persist(container.mainContext, trip: trip, cancelled)

    #expect(trip.timelineBookings(now: now).isEmpty)
}
