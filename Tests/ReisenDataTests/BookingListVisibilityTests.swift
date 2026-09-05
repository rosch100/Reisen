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
@Test("isElapsed Default-Kalender = HotelStayDate.calendar (West-of-GMT kein Fehl-Elapsed)")
func trip_isElapsed_defaultCalendarIgnoresDeviceWestOfGMT() {
    let end = HotelStayDate.dateOnly(year: 2026, month: 9, day: 5)
    let trip = SDTrip(
        title: "West",
        startDate: HotelStayDate.dateOnly(year: 2026, month: 9, day: 1),
        endDate: end
    )
    // 5.9. GMT-Mittag: am Endtag noch aktuell.
    let now = end.addingTimeInterval(12 * 3600)
    #expect(!trip.isElapsed(now: now))

    var west = Calendar(identifier: .gregorian)
    west.timeZone = TimeZone(secondsFromGMT: -8 * 3600)!
    // Geräte-Kalender west-of-GMT: End-Anker wirkt wie 4.9. → fälschlich elapsed.
    #expect(trip.isElapsed(now: now, calendar: west))
}

@MainActor
@Test("Hotel isElapsed Default = HotelStayDate.calendar (West-of-GMT kein Fehl-Elapsed)")
func hotelBooking_isElapsed_defaultCalendarIgnoresDeviceWestOfGMT() {
    let end = HotelStayDate.dateOnly(year: 2026, month: 9, day: 5)
    let hotel = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Hotel",
        startAt: HotelStayDate.dateOnly(year: 2026, month: 9, day: 1),
        endAt: end,
        statusRaw: BookingStatus.confirmed.rawValue
    )
    let now = end.addingTimeInterval(12 * 3600)
    #expect(!hotel.isElapsed(now: now))
    #expect(hotel.listInclusionCalendar.timeZone.secondsFromGMT() == 0)

    var west = Calendar(identifier: .gregorian)
    west.timeZone = TimeZone(secondsFromGMT: -8 * 3600)!
    #expect(hotel.isElapsed(now: now, calendar: west))

    let flight = SDBooking(
        providerRaw: ProviderID.manual.rawValue,
        bookingTypeRaw: BookingType.flight.rawValue,
        title: "Flight",
        startAt: end.addingTimeInterval(-3600),
        endAt: end,
        statusRaw: BookingStatus.confirmed.rawValue
    )
    #expect(flight.listInclusionCalendar.timeZone.secondsFromGMT() == Calendar.current.timeZone.secondsFromGMT())
}

@MainActor
@Test("listGapBadgeCount Default-Kalender = HotelStayDate.calendar (West-of-GMT)")
func listGapBadgeCount_defaultCalendarIgnoresDeviceWestOfGMT() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let end = HotelStayDate.dateOnly(year: 2026, month: 9, day: 10)
    let trip = SDTrip(
        title: "Gaps",
        startDate: HotelStayDate.dateOnly(year: 2026, month: 9, day: 1),
        endDate: end
    )
    let early = SDBooking(
        providerRaw: ProviderID.check24.rawValue,
        bookingTypeRaw: BookingType.activity.rawValue,
        title: "Early",
        startAt: HotelStayDate.dateOnly(year: 2026, month: 9, day: 1),
        endAt: HotelStayDate.dateOnly(year: 2026, month: 9, day: 1).addingTimeInterval(3600),
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: trip
    )
    let late = SDBooking(
        providerRaw: ProviderID.check24.rawValue,
        bookingTypeRaw: BookingType.activity.rawValue,
        title: "Late",
        startAt: HotelStayDate.dateOnly(year: 2026, month: 9, day: 8),
        endAt: HotelStayDate.dateOnly(year: 2026, month: 9, day: 8).addingTimeInterval(3600),
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: trip
    )
    trip.bookings = [early, late]
    context.insert(trip)
    context.insert(early)
    context.insert(late)
    try context.save()

    let now = HotelStayDate.dateOnly(year: 2026, month: 9, day: 5).addingTimeInterval(12 * 3600)
    #expect(trip.completeness().hasTimeGaps)
    #expect(trip.listGapBadgeCount(now: now) == 1)

    var west = Calendar(identifier: .gregorian)
    west.timeZone = TimeZone(secondsFromGMT: -8 * 3600)!
    // Mit west: End-Anker 10.9. GMT wirkt wie 9.9. lokal — Badge kann trotzdem greifen.
    // Härterer Fall: now am letzten Trip-Tag; west verschiebt End-Tag vor today → Badge weg.
    let lastDayNoon = end.addingTimeInterval(12 * 3600)
    #expect(trip.listGapBadgeCount(now: lastDayNoon) == 1)
    #expect(trip.listGapBadgeCount(calendar: west, now: lastDayNoon) == nil)
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

@MainActor
@Test func sidebarChildBookings_elapsedTripIncludesPastProviderBookings() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let trip = makeTrip()
    let pastSynced = makeBooking(start: pastSyncedAt, provider: .getYourGuide, trip: trip)
    let pastManual = makeBooking(start: pastManualAt, provider: .manual, trip: trip)
    let cancelled = makeBooking(
        start: pastSyncedAt,
        provider: .check24,
        trip: trip,
        status: .cancelled
    )
    trip.bookings = [pastSynced, pastManual, cancelled]
    try persist(container.mainContext, trip: trip, pastSynced, pastManual, cancelled)

    let currentKids = trip.sidebarChildBookings(tripIsElapsed: false, now: now)
    #expect(Set(currentKids.map(\.id)) == Set([pastManual.id]))

    let elapsedKids = trip.sidebarChildBookings(tripIsElapsed: true, now: now)
    #expect(Set(elapsedKids.map(\.id)) == Set([pastSynced.id, pastManual.id]))
    #expect(elapsedKids.map(\.id) == [pastSynced.id, pastManual.id])
}

