import Testing
import SwiftData
import Foundation
import ReisenData
import ReisenDomain

@MainActor
@Test func cancellationDeadlineLinkRepositoryUpsertUpdatesByLogicalKey() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let repo = SwiftDataCancellationDeadlineLinkRepository(modelContext: container.mainContext)

    let tripID = UUID()
    let bookingID = UUID()
    let deadlineID = UUID()

    let first = CancellationDeadlineLink(
        ownerTripID: tripID,
        ownerBookingID: bookingID,
        cancellationDeadlineID: deadlineID,
        leadDays: 7,
        eventIdentifier: "E1",
        reminderIdentifier: "R1",
        lastSyncedAt: Date(timeIntervalSince1970: 1_700_000)
    )
    try repo.upsert(first)
    try repo.save()

    let stored1 = try repo.fetchLinks(forCancellationDeadlineID: deadlineID).first
    #expect(stored1?.eventIdentifier == "E1")
    #expect(stored1?.reminderIdentifier == "R1")

    let second = CancellationDeadlineLink(
        id: UUID(),
        ownerTripID: tripID,
        ownerBookingID: bookingID,
        cancellationDeadlineID: deadlineID,
        leadDays: 7,
        eventIdentifier: "E2",
        reminderIdentifier: "R2",
        lastSyncedAt: Date(timeIntervalSince1970: 1_700_111)
    )
    try repo.upsert(second)
    try repo.save()

    let all = try repo.fetchLinks(forCancellationDeadlineID: deadlineID)
    #expect(all.count == 1)
    let stored2 = all.first
    #expect(stored2?.eventIdentifier == "E2")
    #expect(stored2?.reminderIdentifier == "R2")
    #expect(stored2?.lastSyncedAt?.timeIntervalSince1970 == 1_700_111)
}

@MainActor
@Test func cancellationDeadlineLinkRepositoryDeleteByTripRemovesAllRoles() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let repo = SwiftDataCancellationDeadlineLinkRepository(modelContext: container.mainContext)

    let tripID = UUID()
    let deadlineID = UUID()

    try repo.upsert(
        CancellationDeadlineLink(
            ownerTripID: tripID,
            ownerBookingID: UUID(),
            cancellationDeadlineID: deadlineID,
            leadDays: 1,
            eventIdentifier: "E1",
            reminderIdentifier: "R1"
        )
    )
    try repo.upsert(
        CancellationDeadlineLink(
            ownerTripID: tripID,
            ownerBookingID: UUID(),
            cancellationDeadlineID: deadlineID,
            leadDays: 3,
            eventIdentifier: "E2",
            reminderIdentifier: "R2"
        )
    )
    try repo.save()

    #expect(try repo.fetchLinks(forTripID: tripID).count == 2)

    try repo.deleteLinks(forTripID: tripID)
    try repo.save()

    #expect(try repo.fetchLinks(forTripID: tripID).isEmpty)
}
