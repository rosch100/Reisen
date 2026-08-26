import Foundation
import SwiftData
import ReisenDomain

enum SwiftDataPreTravelHintLinkUpsert {
    static func upsert(_ link: PreTravelHintLink, in context: ModelContext) throws {
        let bookingID = link.ownerBookingID
        let leadDays = link.leadDays

        let descriptor = FetchDescriptor<SDPreTravelHintLink>(
            predicate: #Predicate {
                $0.ownerBookingID == bookingID && $0.leadDays == leadDays
            }
        )
        let existing = try context.fetch(descriptor).first

        let model: SDPreTravelHintLink
        if let existing {
            model = existing
        } else {
            model = SDPreTravelHintLink(
                id: link.id,
                ownerTripID: link.ownerTripID,
                ownerBookingID: link.ownerBookingID,
                leadDays: link.leadDays,
                eventIdentifier: link.eventIdentifier,
                reminderIdentifier: link.reminderIdentifier,
                lastSyncedAt: link.lastSyncedAt
            )
            context.insert(model)
        }

        model.ownerTripID = link.ownerTripID
        model.ownerBookingID = link.ownerBookingID
        model.leadDays = link.leadDays
        model.eventIdentifier = link.eventIdentifier
        model.reminderIdentifier = link.reminderIdentifier
        model.lastSyncedAt = link.lastSyncedAt
    }
}
