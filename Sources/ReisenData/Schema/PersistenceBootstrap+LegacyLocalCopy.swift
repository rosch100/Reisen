import Foundation
import SwiftData

extension PersistenceBootstrap {
    static func copyLocalReminders(from source: ModelContext, to target: ModelContext) throws {
        let reminders = try source.fetch(FetchDescriptor<SDReminder>())
        for reminder in reminders {
            let copy = SDReminder(
                id: reminder.id,
                fireAt: reminder.fireAt,
                targetRaw: reminder.targetRaw,
                channelRaw: reminder.channelRaw,
                statusRaw: reminder.statusRaw,
                title: reminder.title,
                notes: reminder.notes,
                cancellationDeadlineID: reminder.cancellationDeadlineID,
                gapID: reminder.gapID,
                externalAlarmId: reminder.externalAlarmId
            )
            target.insert(copy)
        }
    }

    static func copyLocalCalendarLinks(from source: ModelContext, to target: ModelContext) throws {
        let calendarLinks = try source.fetch(FetchDescriptor<SDCalendarEventLink>())
        for link in calendarLinks {
            let copy = SDCalendarEventLink(
                id: link.id,
                roleRaw: link.roleRaw,
                ownerTripID: link.ownerTripID,
                ownerBookingID: link.ownerBookingID,
                eventIdentifier: link.eventIdentifier,
                calendarItemExternalIdentifier: link.calendarItemExternalIdentifier,
                lastSyncedAt: link.lastSyncedAt
            )
            target.insert(copy)
        }
    }

    static func copyLocalDeadlineLinks(from source: ModelContext, to target: ModelContext) throws {
        let deadlineLinks = try source.fetch(FetchDescriptor<SDCancellationDeadlineLink>())
        for link in deadlineLinks {
            let copy = SDCancellationDeadlineLink(
                id: link.id,
                ownerTripID: link.ownerTripID,
                ownerBookingID: link.ownerBookingID,
                cancellationDeadlineID: link.cancellationDeadlineID,
                leadDays: link.leadDays,
                eventIdentifier: link.eventIdentifier,
                reminderIdentifier: link.reminderIdentifier,
                lastSyncedAt: link.lastSyncedAt
            )
            target.insert(copy)
        }
    }

    static func copyLocalEntities(from source: ModelContext, to target: ModelContext) throws {
        try copyLocalReminders(from: source, to: target)
        try copyLocalCalendarLinks(from: source, to: target)
        try copyLocalDeadlineLinks(from: source, to: target)
    }
}
