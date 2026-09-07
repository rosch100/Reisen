import Foundation
import ReisenDomain

public struct CancellationDeadlineSyncPersistPlan: Sendable, Equatable {
    public var upserts: [CancellationDeadlineLink]
    public var deleteIDs: [UUID]
    public var eventSaveCount: Int
    public var reminderSaveCount: Int
    public var durationMilliseconds: Int

    public init(
        upserts: [CancellationDeadlineLink],
        deleteIDs: [UUID],
        eventSaveCount: Int,
        reminderSaveCount: Int,
        durationMilliseconds: Int
    ) {
        self.upserts = upserts
        self.deleteIDs = deleteIDs
        self.eventSaveCount = eventSaveCount
        self.reminderSaveCount = reminderSaveCount
        self.durationMilliseconds = durationMilliseconds
    }

    public var didChangeLinks: Bool {
        !upserts.isEmpty || !deleteIDs.isEmpty
    }
}

@MainActor
public enum CancellationDeadlineLinkPersister {
    public static func apply(
        _ plan: CancellationDeadlineSyncPersistPlan,
        linkRepo: CancellationDeadlineLinkRepository
    ) throws {
        for link in plan.upserts {
            try linkRepo.upsert(link)
        }
        if !plan.deleteIDs.isEmpty {
            try linkRepo.deleteLinks(ids: plan.deleteIDs)
        }
        if plan.didChangeLinks {
            try linkRepo.save()
        }
    }
}
