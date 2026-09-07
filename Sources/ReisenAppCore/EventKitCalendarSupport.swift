import Foundation
@preconcurrency import EventKit
import ReisenDomain

/// Shared EventKit calendar title + ensure/create for Bridge and Deadline-Writer.
enum EventKitCalendarSupport {
    static func title(
        for trip: Trip,
        kind: EKEntityType,
        calendarTitleMode: CalendarTitleMode,
        eventCalendarTitle: String,
        reminderCalendarTitle: String
    ) -> String {
        switch calendarTitleMode {
        case .fixed:
            return kind == .event ? eventCalendarTitle : reminderCalendarTitle
        case .tripTitle:
            return trip.title
        }
    }

    /// - Parameter saveCalendarCommit: Bridge uses `true`; Deadline-Writer `false` (Trip-Batch-Commit).
    static func ensureCalendar(
        named title: String,
        kind: EKEntityType,
        store: EKEventStore,
        createIfMissing: Bool,
        saveCalendarCommit: Bool
    ) throws -> (calendar: EKCalendar, didCreate: Bool) {
        if let existing = store.calendars(for: kind).first(where: { $0.title == title }) {
            return (existing, false)
        }

        // Parität: fehlender Zielkalender wird angelegt (iOS ↔ macOS).
        // createIfMissing bleibt API-Parität; Durchsetzen wie bisher.
        _ = createIfMissing
        let calendar = try createCalendar(
            named: title,
            kind: kind,
            store: store,
            commit: saveCalendarCommit
        )
        return (calendar, true)
    }

    static func createCalendar(
        named title: String,
        kind: EKEntityType,
        store: EKEventStore,
        commit: Bool
    ) throws -> EKCalendar {
        let calendar = EKCalendar(for: kind, eventStore: store)
        calendar.title = title

        if kind == .event, let source = store.defaultCalendarForNewEvents?.source {
            calendar.source = source
        } else if kind == .reminder, let def = store.defaultCalendarForNewReminders(), let source = def.source {
            calendar.source = source
        } else {
            calendar.source = store.sources.first
        }

        do {
            try store.saveCalendar(calendar, commit: commit)
        } catch {
            let systemMessage = error.localizedDescription
            if systemMessage.localizedCaseInsensitiveContains("keine kalender hinzugefügt oder entfernt werden")
                || systemMessage.localizedCaseInsensitiveContains("dürfen keine kalender hinzugefügt oder entfernt werden") {
                throw LocalEventKitBridgeError.calendarModificationDenied
            }
            if kind == .event { throw LocalEventKitBridgeError.calendarWriteFailed }
            throw LocalEventKitBridgeError.reminderWriteFailed
        }

        return calendar
    }
}
