import Foundation
import Testing
@testable import ReisenAppCore
import ReisenDomain
import ReisenData

@MainActor
@Suite("CancellationDeadlineLinkPersister")
struct CancellationDeadlineLinkPersisterTests {
    @Test func apply_upsertsAndDeletesThenSaves() throws {
        let container = try PersistenceBootstrap.makeInMemoryContainer()
        let repo = SwiftDataCancellationDeadlineLinkRepository(modelContext: container.mainContext)

        let keepID = UUID()
        let dropID = UUID()
        let tripID = UUID()
        let bookingID = UUID()
        let deadlineID = UUID()

        try repo.upsert(
            CancellationDeadlineLink(
                id: dropID,
                ownerTripID: tripID,
                ownerBookingID: bookingID,
                cancellationDeadlineID: deadlineID,
                leadDays: 7,
                eventIdentifier: "old-event",
                reminderIdentifier: nil,
                lastSyncedAt: Date(timeIntervalSince1970: 1)
            )
        )
        try repo.save()

        let plan = CancellationDeadlineSyncPersistPlan(
            upserts: [
                CancellationDeadlineLink(
                    id: keepID,
                    ownerTripID: tripID,
                    ownerBookingID: bookingID,
                    cancellationDeadlineID: deadlineID,
                    leadDays: 3,
                    eventIdentifier: "new-event",
                    reminderIdentifier: "new-reminder",
                    lastSyncedAt: Date(timeIntervalSince1970: 2)
                )
            ],
            deleteIDs: [dropID],
            eventSaveCount: 1,
            reminderSaveCount: 1,
            durationMilliseconds: 12
        )

        try CancellationDeadlineLinkPersister.apply(plan, linkRepo: repo)

        let remaining = try repo.fetchAll()
        #expect(remaining.map(\.id) == [keepID])
        #expect(remaining[0].eventIdentifier == "new-event")
    }

    @Test func apply_emptyPlan_doesNotRequireSaveChanges() throws {
        let container = try PersistenceBootstrap.makeInMemoryContainer()
        let repo = SwiftDataCancellationDeadlineLinkRepository(modelContext: container.mainContext)
        let plan = CancellationDeadlineSyncPersistPlan(
            upserts: [],
            deleteIDs: [],
            eventSaveCount: 0,
            reminderSaveCount: 0,
            durationMilliseconds: 0
        )
        try CancellationDeadlineLinkPersister.apply(plan, linkRepo: repo)
    }
}
