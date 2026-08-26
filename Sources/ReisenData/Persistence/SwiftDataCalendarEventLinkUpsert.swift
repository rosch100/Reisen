import Foundation
import SwiftData
import ReisenDomain

enum SwiftDataCalendarEventLinkUpsert {
    static func upsert(_ link: CalendarEventLink, in context: ModelContext) throws {
        let existing = try SwiftDataCalendarEventLinkFind.existing(for: link, in: context)
        let model: SDCalendarEventLink

        if let existing {
            model = existing
        } else {
            model = SDCalendarEventLink(
                id: link.id,
                roleRaw: link.role.rawValue,
                ownerTripID: link.ownerTripID,
                ownerBookingID: link.ownerBookingID,
                eventIdentifier: link.eventIdentifier,
                calendarItemExternalIdentifier: link.calendarItemExternalIdentifier,
                lastSyncedAt: link.lastSyncedAt
            )
            context.insert(model)
        }

        model.roleRaw = link.role.rawValue
        model.ownerTripID = link.ownerTripID
        model.ownerBookingID = link.ownerBookingID
        model.eventIdentifier = link.eventIdentifier
        model.calendarItemExternalIdentifier = link.calendarItemExternalIdentifier
        model.lastSyncedAt = link.lastSyncedAt
    }
}
