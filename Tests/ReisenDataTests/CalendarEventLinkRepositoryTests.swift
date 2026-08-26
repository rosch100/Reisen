import Testing
import SwiftData
import Foundation
import ReisenData
import ReisenDomain

@MainActor
@Test func calendarEventLinkRepositoryUpsertUpdatesByLogicalKey() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let repo = SwiftDataCalendarEventLinkRepository(modelContext: container.mainContext)

    let tripID = UUID()
    let bookingID = UUID()

    let first = CalendarEventLink(
        role: .hotelStay,
        ownerTripID: tripID,
        ownerBookingID: bookingID,
        eventIdentifier: "E1",
        calendarItemExternalIdentifier: "C1",
        lastSyncedAt: Date(timeIntervalSince1970: 1_700_000)
    )
    try repo.upsert(first)
    try repo.save()

    let stored1 = try repo.fetchLinks(forTripID: tripID).first
    #expect(stored1?.eventIdentifier == "E1")
    #expect(stored1?.calendarItemExternalIdentifier == "C1")

    let second = CalendarEventLink(
        id: UUID(),
        role: .hotelStay,
        ownerTripID: tripID,
        ownerBookingID: bookingID,
        eventIdentifier: "E2",
        calendarItemExternalIdentifier: "C2",
        lastSyncedAt: Date(timeIntervalSince1970: 1_700_111)
    )
    try repo.upsert(second)
    try repo.save()

    let all = try repo.fetchLinks(forTripID: tripID)
    #expect(all.count == 1)
    let stored2 = all.first
    #expect(stored2?.eventIdentifier == "E2")
    #expect(stored2?.calendarItemExternalIdentifier == "C2")
    #expect(stored2?.lastSyncedAt?.timeIntervalSince1970 == 1_700_111)
}

@MainActor
@Test func calendarEventLinkRepositoryDeleteByTripRemovesAllRoles() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let repo = SwiftDataCalendarEventLinkRepository(modelContext: container.mainContext)

    let tripID = UUID()

    try repo.upsert(CalendarEventLink(
        role: .tripStart,
        ownerTripID: tripID,
        ownerBookingID: nil,
        eventIdentifier: "E1"
    ))
    try repo.upsert(CalendarEventLink(
        role: .tripEnd,
        ownerTripID: tripID,
        ownerBookingID: nil,
        eventIdentifier: "E2"
    ))
    try repo.save()

    #expect(try repo.fetchLinks(forTripID: tripID).count == 2)

    try repo.deleteLinks(forTripID: tripID)
    try repo.save()

    #expect(try repo.fetchLinks(forTripID: tripID).isEmpty)
}
