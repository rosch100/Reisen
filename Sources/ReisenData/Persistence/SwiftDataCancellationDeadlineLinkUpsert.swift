import Foundation
import SwiftData
import ReisenDomain

enum SwiftDataCancellationDeadlineLinkUpsert {
    static func upsert(_ link: CancellationDeadlineLink, in context: ModelContext) throws {
        let deadlineID = link.cancellationDeadlineID
        let leadDays = link.leadDays

        let descriptor = FetchDescriptor<SDCancellationDeadlineLink>(
            predicate: #Predicate {
                $0.cancellationDeadlineID == deadlineID && $0.leadDays == leadDays
            }
        )
        let existing = try context.fetch(descriptor).first

        let model: SDCancellationDeadlineLink
        if let existing {
            model = existing
        } else {
            model = SDCancellationDeadlineLink(
                id: link.id,
                ownerTripID: link.ownerTripID,
                ownerBookingID: link.ownerBookingID,
                cancellationDeadlineID: link.cancellationDeadlineID,
                leadDays: link.leadDays,
                eventIdentifier: link.eventIdentifier,
                reminderIdentifier: link.reminderIdentifier,
                lastSyncedAt: link.lastSyncedAt
            )
            context.insert(model)
        }

        model.ownerTripID = link.ownerTripID
        model.ownerBookingID = link.ownerBookingID
        model.eventIdentifier = link.eventIdentifier
        model.reminderIdentifier = link.reminderIdentifier
        model.lastSyncedAt = link.lastSyncedAt
    }
}
