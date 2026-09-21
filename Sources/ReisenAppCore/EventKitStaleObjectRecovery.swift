import Foundation
@preconcurrency import EventKit
import ReisenDiagnostics
import ReisenDomain

enum EventKitStaleObjectRecovery {
    static let objectNotFoundDomain = "EKCADErrorDomain"
    static let objectNotFoundCode = 1010

    static func isObjectNotFound(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == objectNotFoundDomain, nsError.code == objectNotFoundCode {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isObjectNotFound(underlying)
        }
        return false
    }

    static func recordRecovery(component: String, itemKind: String, reason: String) {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .manual,
                        operation: "eventkit_side_effect"
                    ),
                    component: component,
                    phase: "stale_object_recovery",
                    event: "eventkit_stale_item_recovered",
                    result: .skipped,
                    reason: "\(itemKind):\(reason)",
                    visibility: .publicDiagnostic
                )
            )
        }
    }

    static func linksWithoutEventKitIdentifiers(_ links: [CancellationDeadlineLink]) -> [CancellationDeadlineLink] {
        links.map { link in
            CancellationDeadlineLink(
                id: link.id,
                ownerTripID: link.ownerTripID,
                ownerBookingID: link.ownerBookingID,
                cancellationDeadlineID: link.cancellationDeadlineID,
                leadDays: link.leadDays,
                eventIdentifier: "",
                reminderIdentifier: nil,
                lastSyncedAt: link.lastSyncedAt
            )
        }
    }
}

protocol EventKitStaleEventSaving: AnyObject {
    associatedtype EventHandle
    func event(withIdentifier identifier: String) -> EventHandle?
    func makeEvent() -> EventHandle
    func save(_ event: EventHandle, span: EKSpan, commit: Bool) throws
    func remove(_ event: EventHandle, span: EKSpan, commit: Bool) throws
}

enum EventKitStaleEventOperations {
    static func upsertEvent<Store: EventKitStaleEventSaving>(
        store: Store,
        existingIdentifier: String?,
        component: String,
        configure: (Store.EventHandle) -> Void,
        span: EKSpan = .thisEvent,
        commit: Bool
    ) throws -> Store.EventHandle {
        let event = resolveEvent(store: store, existingIdentifier: existingIdentifier)
        configure(event)
        do {
            try store.save(event, span: span, commit: commit)
            return event
        } catch {
            guard EventKitStaleObjectRecovery.isObjectNotFound(error) else { throw error }
            EventKitStaleObjectRecovery.recordRecovery(
                component: component,
                itemKind: "event",
                reason: "save_retry"
            )
            let fresh = store.makeEvent()
            configure(fresh)
            try store.save(fresh, span: span, commit: commit)
            return fresh
        }
    }

    static func removeEventIfPresent<Store: EventKitStaleEventSaving>(
        store: Store,
        identifier: String,
        component: String,
        span: EKSpan = .thisEvent,
        commit: Bool
    ) throws {
        guard !identifier.isEmpty, let event = store.event(withIdentifier: identifier) else { return }
        do {
            try store.remove(event, span: span, commit: commit)
        } catch {
            guard EventKitStaleObjectRecovery.isObjectNotFound(error) else { throw error }
            EventKitStaleObjectRecovery.recordRecovery(
                component: component,
                itemKind: "event",
                reason: "remove_already_gone"
            )
        }
    }

    private static func resolveEvent<Store: EventKitStaleEventSaving>(
        store: Store,
        existingIdentifier: String?
    ) -> Store.EventHandle {
        if let existingIdentifier,
           !existingIdentifier.isEmpty,
           let existing = store.event(withIdentifier: existingIdentifier) {
            return existing
        }
        return store.makeEvent()
    }
}

protocol EventKitStaleReminderSaving: AnyObject {
    associatedtype ReminderHandle
    func reminder(withIdentifier identifier: String) -> ReminderHandle?
    func makeReminder() -> ReminderHandle
    func save(_ reminder: ReminderHandle, commit: Bool) throws
    func remove(_ reminder: ReminderHandle, commit: Bool) throws
}

enum EventKitStaleReminderOperations {
    static func upsertReminder<Store: EventKitStaleReminderSaving>(
        store: Store,
        existingIdentifier: String?,
        component: String,
        configure: (Store.ReminderHandle) -> Void,
        commit: Bool
    ) throws -> Store.ReminderHandle {
        let reminder = resolveReminder(store: store, existingIdentifier: existingIdentifier)
        configure(reminder)
        do {
            try store.save(reminder, commit: commit)
            return reminder
        } catch {
            guard EventKitStaleObjectRecovery.isObjectNotFound(error) else { throw error }
            EventKitStaleObjectRecovery.recordRecovery(
                component: component,
                itemKind: "reminder",
                reason: "save_retry"
            )
            let fresh = store.makeReminder()
            configure(fresh)
            try store.save(fresh, commit: commit)
            return fresh
        }
    }

    static func removeReminderIfPresent<Store: EventKitStaleReminderSaving>(
        store: Store,
        identifier: String,
        component: String,
        commit: Bool
    ) throws {
        guard !identifier.isEmpty, let reminder = store.reminder(withIdentifier: identifier) else { return }
        do {
            try store.remove(reminder, commit: commit)
        } catch {
            guard EventKitStaleObjectRecovery.isObjectNotFound(error) else { throw error }
            EventKitStaleObjectRecovery.recordRecovery(
                component: component,
                itemKind: "reminder",
                reason: "remove_already_gone"
            )
        }
    }

    private static func resolveReminder<Store: EventKitStaleReminderSaving>(
        store: Store,
        existingIdentifier: String?
    ) -> Store.ReminderHandle {
        if let existingIdentifier,
           !existingIdentifier.isEmpty,
           let existing = store.reminder(withIdentifier: existingIdentifier) {
            return existing
        }
        return store.makeReminder()
    }
}

extension EKEventStore: EventKitStaleEventSaving {
    typealias EventHandle = EKEvent

    func makeEvent() -> EKEvent {
        EKEvent(eventStore: self)
    }
}

extension EKEventStore: EventKitStaleReminderSaving {
    typealias ReminderHandle = EKReminder

    func makeReminder() -> EKReminder {
        EKReminder(eventStore: self)
    }

    func reminder(withIdentifier identifier: String) -> EKReminder? {
        calendarItem(withIdentifier: identifier) as? EKReminder
    }
}
