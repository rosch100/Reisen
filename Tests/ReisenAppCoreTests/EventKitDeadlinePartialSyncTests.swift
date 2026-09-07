import Foundation
import Testing
@testable import ReisenAppCore
import ReisenDomain

@Suite("EventKitDeadlinePartialSync")
struct EventKitDeadlinePartialSyncTests {
    private enum SampleCause: Error {
        case tripFailed
    }

    @Test func partialSyncError_carriesPlanAndCauseForCallerApply() {
        let upsert = CancellationDeadlineLink(
            id: UUID(),
            ownerTripID: UUID(),
            ownerBookingID: UUID(),
            cancellationDeadlineID: UUID(),
            leadDays: 7,
            eventIdentifier: "evt-1",
            reminderIdentifier: nil,
            lastSyncedAt: Date()
        )
        let plan = CancellationDeadlineSyncPersistPlan(
            upserts: [upsert],
            deleteIDs: [],
            eventSaveCount: 1,
            reminderSaveCount: 0,
            durationMilliseconds: 12
        )
        let error = EventKitDeadlinePartialSyncError(plan: plan, cause: SampleCause.tripFailed)

        #expect(error.plan.upserts.map(\.id) == [upsert.id])
        #expect(error.plan.eventSaveCount == 1)
        #expect(error.cause is SampleCause)
    }
}
