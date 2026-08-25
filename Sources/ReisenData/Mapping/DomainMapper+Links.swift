import Foundation
import ReisenDomain

extension DomainMapper {
    public static func calendarEventLink(from model: SDCalendarEventLink) -> CalendarEventLink {
        CalendarEventLink(
            id: model.id,
            role: CalendarEventRole(rawValue: model.roleRaw) ?? .tripStart,
            ownerTripID: model.ownerTripID,
            ownerBookingID: model.ownerBookingID,
            eventIdentifier: model.eventIdentifier,
            calendarItemExternalIdentifier: model.calendarItemExternalIdentifier,
            lastSyncedAt: model.lastSyncedAt
        )
    }

    public static func cancellationDeadlineLink(from model: SDCancellationDeadlineLink) -> CancellationDeadlineLink {
        CancellationDeadlineLink(
            id: model.id,
            ownerTripID: model.ownerTripID,
            ownerBookingID: model.ownerBookingID,
            cancellationDeadlineID: model.cancellationDeadlineID,
            leadDays: model.leadDays,
            eventIdentifier: model.eventIdentifier,
            reminderIdentifier: model.reminderIdentifier,
            lastSyncedAt: model.lastSyncedAt
        )
    }

    public static func preTravelHintLink(from model: SDPreTravelHintLink) -> PreTravelHintLink {
        PreTravelHintLink(
            id: model.id,
            ownerTripID: model.ownerTripID,
            ownerBookingID: model.ownerBookingID,
            leadDays: model.leadDays,
            eventIdentifier: model.eventIdentifier,
            reminderIdentifier: model.reminderIdentifier,
            lastSyncedAt: model.lastSyncedAt
        )
    }
}
