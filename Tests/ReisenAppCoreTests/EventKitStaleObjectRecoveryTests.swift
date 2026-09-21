import Foundation
import Testing
@testable import ReisenAppCore
import ReisenDomain
@preconcurrency import EventKit

@Suite("EventKitStaleObjectRecovery")
struct EventKitStaleObjectRecoveryTests {
    private static func objectNotFoundError() -> NSError {
        NSError(
            domain: EventKitStaleObjectRecovery.objectNotFoundDomain,
            code: EventKitStaleObjectRecovery.objectNotFoundCode,
            userInfo: [NSLocalizedDescriptionKey: "Objekt nicht gefunden. Möglicherweise wurde es gelöscht."]
        )
    }

    @Test func isObjectNotFound_detectsEKCAD1010() {
        #expect(EventKitStaleObjectRecovery.isObjectNotFound(Self.objectNotFoundError()))
    }

    @Test func isObjectNotFound_detectsWrapped1010() {
        let wrapped = NSError(
            domain: "SomeDomain",
            code: 1,
            userInfo: [NSUnderlyingErrorKey: Self.objectNotFoundError()]
        )
        #expect(EventKitStaleObjectRecovery.isObjectNotFound(wrapped))
    }

    @Test func isObjectNotFound_rejectsUnrelatedErrors() {
        let other = NSError(domain: "OtherDomain", code: 42)
        #expect(!EventKitStaleObjectRecovery.isObjectNotFound(other))
    }

    @Test func linksWithoutEventKitIdentifiers_clearsStoredIDs() {
        let link = CancellationDeadlineLink(
            ownerTripID: UUID(),
            cancellationDeadlineID: UUID(),
            leadDays: 7,
            eventIdentifier: "evt-stale",
            reminderIdentifier: "rem-stale"
        )

        let stripped = EventKitStaleObjectRecovery.linksWithoutEventKitIdentifiers([link])

        #expect(stripped.count == 1)
        #expect(stripped[0].eventIdentifier.isEmpty)
        #expect(stripped[0].reminderIdentifier == nil)
        #expect(stripped[0].id == link.id)
    }

    final class FakeEventRecord: @unchecked Sendable {
        var identifier: String
        var title: String?

        init(identifier: String) {
            self.identifier = identifier
        }
    }

    final class FakeEventStore: EventKitStaleEventSaving, @unchecked Sendable {
        typealias EventHandle = FakeEventRecord

        var eventsByIdentifier: [String: FakeEventRecord] = [:]
        var saveCalls: [(identifier: String, commit: Bool)] = []
        var removeCalls: [String] = []
        var failSaveIdentifiers: Set<String> = []
        var failRemoveIdentifiers: Set<String> = []
        private var nextIdentifier = 0

        func event(withIdentifier identifier: String) -> FakeEventRecord? {
            eventsByIdentifier[identifier]
        }

        func makeEvent() -> FakeEventRecord {
            nextIdentifier += 1
            let event = FakeEventRecord(identifier: "new-\(nextIdentifier)")
            eventsByIdentifier[event.identifier] = event
            return event
        }

        func save(_ event: FakeEventRecord, span: EKSpan, commit: Bool) throws {
            saveCalls.append((event.identifier, commit))
            if failSaveIdentifiers.contains(event.identifier) {
                throw EventKitStaleObjectRecoveryTests.objectNotFoundError()
            }
        }

        func remove(_ event: FakeEventRecord, span: EKSpan, commit: Bool) throws {
            removeCalls.append(event.identifier)
            if failRemoveIdentifiers.contains(event.identifier) {
                throw EventKitStaleObjectRecoveryTests.objectNotFoundError()
            }
            eventsByIdentifier.removeValue(forKey: event.identifier)
        }
    }

    final class FakeReminderRecord: @unchecked Sendable {
        var identifier: String
        var title: String?

        init(identifier: String) {
            self.identifier = identifier
        }
    }

    final class FakeReminderStore: EventKitStaleReminderSaving, @unchecked Sendable {
        typealias ReminderHandle = FakeReminderRecord

        var remindersByIdentifier: [String: FakeReminderRecord] = [:]
        var saveCalls: [(identifier: String, commit: Bool)] = []
        var failSaveIdentifiers: Set<String> = []
        private var nextIdentifier = 0

        func reminder(withIdentifier identifier: String) -> FakeReminderRecord? {
            remindersByIdentifier[identifier]
        }

        func makeReminder() -> FakeReminderRecord {
            nextIdentifier += 1
            let reminder = FakeReminderRecord(identifier: "rem-\(nextIdentifier)")
            remindersByIdentifier[reminder.identifier] = reminder
            return reminder
        }

        func save(_ reminder: FakeReminderRecord, commit: Bool) throws {
            saveCalls.append((reminder.identifier, commit))
            if failSaveIdentifiers.contains(reminder.identifier) {
                throw EventKitStaleObjectRecoveryTests.objectNotFoundError()
            }
        }

        func remove(_ reminder: FakeReminderRecord, commit: Bool) throws {}
    }

    @Test func upsertEvent_retriesWithFreshEventWhenSaveReturns1010() throws {
        let store = FakeEventStore()
        let stale = FakeEventRecord(identifier: "stale-event")
        store.eventsByIdentifier[stale.identifier] = stale
        store.failSaveIdentifiers = [stale.identifier]

        let saved = try EventKitStaleEventOperations.upsertEvent(
            store: store,
            existingIdentifier: stale.identifier,
            component: "Test",
            configure: { $0.title = "Stornofrist" },
            commit: false
        )

        #expect(saved.identifier == "new-1")
        #expect(store.saveCalls.count == 2)
        #expect(store.saveCalls[0].identifier == "stale-event")
        #expect(store.saveCalls[1].identifier == "new-1")
    }

    @Test func removeEventIfPresent_ignores1010WhenObjectAlreadyDeleted() throws {
        let store = FakeEventStore()
        let stale = FakeEventRecord(identifier: "stale-event")
        store.eventsByIdentifier[stale.identifier] = stale
        store.failRemoveIdentifiers = [stale.identifier]

        try EventKitStaleEventOperations.removeEventIfPresent(
            store: store,
            identifier: stale.identifier,
            component: "Test",
            commit: false
        )

        #expect(store.removeCalls == ["stale-event"])
    }

    @Test func upsertEvent_createsFreshEventWhenStoredIdentifierIsMissing() throws {
        let store = FakeEventStore()

        let saved = try EventKitStaleEventOperations.upsertEvent(
            store: store,
            existingIdentifier: "missing-event",
            component: "Test",
            configure: { $0.title = "Stornofrist" },
            commit: false
        )

        #expect(saved.identifier == "new-1")
        #expect(store.saveCalls.count == 1)
    }

    @Test func upsertReminder_retriesWithFreshReminderWhenSaveReturns1010() throws {
        let store = FakeReminderStore()
        let stale = FakeReminderRecord(identifier: "stale-reminder")
        store.remindersByIdentifier[stale.identifier] = stale
        store.failSaveIdentifiers = [stale.identifier]

        let saved = try EventKitStaleReminderOperations.upsertReminder(
            store: store,
            existingIdentifier: stale.identifier,
            component: "Test",
            configure: { $0.title = "Stornofrist" },
            commit: false
        )

        #expect(saved.identifier == "rem-1")
        #expect(store.saveCalls.count == 2)
        #expect(store.saveCalls[0].identifier == "stale-reminder")
        #expect(store.saveCalls[1].identifier == "rem-1")
    }
}
