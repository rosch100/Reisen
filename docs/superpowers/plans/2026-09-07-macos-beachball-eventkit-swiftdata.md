# macOS Beachball EventKit + SwiftData Implementation Plan

> **Status:** Phase 1 + Phase 2 implementiert (2026-09-07). Checkboxes unten = erledigt, außer manuelle Beachball-/Spin-Acceptance (Task 3 Step 4 / Task 7 Step 4) — außerhalb CI, noch offen.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking. Phase 1 = Task 1–5 (shippable). Phase 2 = Task 6 (Root-Cause-DoD) + Task 7 (Fix erst nach Task 6).

**Goal:** Storno-Deadline-EventKit-Sync blockiert den Main Thread nicht mehr mit synchronen CalendarDaemon-XPC-Saves; SwiftData-HID-Spins werden danach evidenzbasiert behoben.

**Architecture:** EK-Deadline-Schreiben läuft auf `EventKitDeadlineWriter` (`actor`, Batch-`commit` **pro erfolgreichem Trip**, Store-Replace nach Trip-Fehler). `LocalEventKitBridge.syncCancellationDeadlines` bleibt `async throws` (Void): MainActor-Link-Fetch → `await` Writer → `CancellationDeadlineLinkPersister.apply` (nach EK, inkl. PartialSync). `LocalSideEffectCoordinator` und `CalendarSyncing`-Signatur unverändert. Timeline-Semantik unverändert. Phase 2: Root Cause in Spec, dann Fix.

**Tech Stack:** Swift, EventKit, SwiftData, `DiagnosticLogger`/`DiagnosticEvent`, Swift Testing, `Scripts/ci-test.sh`

**Spec:** [`docs/superpowers/specs/2026-09-07-macos-beachball-eventkit-swiftdata-design.md`](../specs/2026-09-07-macos-beachball-eventkit-swiftdata-design.md)

**Spin-Evidenz (außerhalb Repo):** `~/Desktop/Voyenna-spins/` — EventKit 06.09. (`saveEvent` → CADXPC); SwiftData 04.09. (`ContentView.handleProviderPrefsRemoteChange` → `ProviderPreferencesImportGate` + SwiftData)

## Global Constraints

- Kein Debounce-only / Chunked-`Task.yield`-only als „Fix“
- Keine stillen Fallbacks; Teilfehler: nach Batch-`commit` liefert der Writer `EventKitDeadlinePartialSyncError(plan:cause:)`; Bridge wendet `plan` an und wirft `cause` (Diagnostics: `eventkit_deadline_sync_partial_failed`)
- Secrets/PII nicht in Diagnostics (Counts/ms/reasons ok)
- Timeline-Feature-Scope aus `2026-07-21-calendar-timeline-eventkit-design.md` nicht erweitern
- Keine Multi‑MB-`.spin`-Dumps committen
- Commits nur auf explizite User-Anweisung
- Logging + Tests im selben Diff (`reisen-logging-and-tests`)

## File Map

| Datei | Verantwortung |
| --- | --- |
| `Sources/ReisenAppCore/CancellationDeadlineSyncPersistPlan.swift` | `CancellationDeadlineSyncPersistPlan` + `CancellationDeadlineLinkPersister` |
| `Sources/ReisenAppCore/EventKitDeadlineBatchCommit.swift` | Unit-Test-Vertrag für „n× save(commit:false) → 1× commit“; Writer spiegelt dieselbe Semantik mit `EKEventStore` (kein Fake-Store im Produktpfad) |
| `Sources/ReisenAppCore/EventKitCalendarSupport.swift` | SSOT: Kalender-Titel + ensure/create (Bridge `commit:true`, Writer `commit:false`) |
| `Sources/ReisenAppCore/CancellationDeadlineWallClock.swift` | SSOT: Hotel-Offset-Wanduhr-Format für Stornofristen |
| `Sources/ReisenAppCore/EventKitOffsetSkip.swift` | SSOT: EventKit Offset-Skip-Diagnostics |
| `Sources/ReisenAppCore/EventKitDeadlineWriter.swift` | `actor`: Access, Upsert/Delete, Batch-Commit, `EventKitDeadlinePartialSyncError`, kein SwiftData |
| `Sources/ReisenAppCore/LocalEventKitBridge.swift` | Fetch Links → await Writer → Persister (+ PartialSync apply-then-rethrow); Timeline unverändert |
| `Sources/ReisenAppCore/LocalEventKitBridgeError.swift` | Sendable EventKit-Fehler (typealias an Bridge) |
| `Sources/ReisenDomain/Ports/SideEffectPorts.swift` | **unverändert** (Void-`syncCancellationDeadlines`) |
| `Sources/ReisenAppCore/LocalSideEffectCoordinator.swift` | **unverändert** (`try await calendarSync.syncCancellationDeadlines(...)`) |
| `Tests/ReisenAppCoreTests/CancellationDeadlineLinkPersisterTests.swift` | Persist-Vertrag |
| `Tests/ReisenAppCoreTests/EventKitDeadlineBatchCommitTests.swift` | Batch-Commit-Semantik (Fake-Store) |
| `Tests/ReisenAppCoreTests/EventKitDeadlinePartialSyncTests.swift` | PartialSync-Error trägt Plan+Cause |
| Spec + dieser Plan | Phase-2 Root-Cause-Abschnitt (Task 6) |

---

### Task 1: PersistPlan + Persister (RED→GREEN)

**Files:**
- Create: `Sources/ReisenAppCore/CancellationDeadlineSyncPersistPlan.swift`
- Create: `Tests/ReisenAppCoreTests/CancellationDeadlineLinkPersisterTests.swift`
- Test: dieselbe Test-Datei

**Interfaces:**
- Consumes: `CancellationDeadlineLink`, `CancellationDeadlineLinkRepository` (`deleteLinks(ids:)` + `save()` im Domain-Port)
- Produces: `CancellationDeadlineSyncPersistPlan`, `CancellationDeadlineLinkPersister.apply`

- [x] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import ReisenAppCore
import ReisenDomain
import ReisenData

@MainActor
@Suite("CancellationDeadlineLinkPersister")
struct CancellationDeadlineLinkPersisterTests {
    @Test func apply_upsertsAndDeletesThenSaves() throws {
        let container = try PersistenceBootstrap.makeInMemoryContainer()
        let repo = SwiftDataCancellationDeadlineLinkRepository(modelContext: container.mainContext)

        let keepID = UUID()
        let dropID = UUID()
        let tripID = UUID()
        let bookingID = UUID()
        let deadlineID = UUID()

        try repo.upsert(
            CancellationDeadlineLink(
                id: dropID,
                ownerTripID: tripID,
                ownerBookingID: bookingID,
                cancellationDeadlineID: deadlineID,
                leadDays: 7,
                eventIdentifier: "old-event",
                reminderIdentifier: nil,
                lastSyncedAt: Date(timeIntervalSince1970: 1)
            )
        )
        try repo.save()

        let plan = CancellationDeadlineSyncPersistPlan(
            upserts: [
                CancellationDeadlineLink(
                    id: keepID,
                    ownerTripID: tripID,
                    ownerBookingID: bookingID,
                    cancellationDeadlineID: deadlineID,
                    leadDays: 3,
                    eventIdentifier: "new-event",
                    reminderIdentifier: "new-reminder",
                    lastSyncedAt: Date(timeIntervalSince1970: 2)
                )
            ],
            deleteIDs: [dropID],
            eventSaveCount: 1,
            reminderSaveCount: 1,
            durationMilliseconds: 12
        )

        try CancellationDeadlineLinkPersister.apply(plan, linkRepo: repo)

        let remaining = try repo.fetchAll()
        #expect(remaining.map(\.id) == [keepID])
        #expect(remaining[0].eventIdentifier == "new-event")
    }

    @Test func apply_emptyPlan_doesNotRequireSaveChanges() throws {
        let container = try PersistenceBootstrap.makeInMemoryContainer()
        let repo = SwiftDataCancellationDeadlineLinkRepository(modelContext: container.mainContext)
        let plan = CancellationDeadlineSyncPersistPlan(
            upserts: [],
            deleteIDs: [],
            eventSaveCount: 0,
            reminderSaveCount: 0,
            durationMilliseconds: 0
        )
        try CancellationDeadlineLinkPersister.apply(plan, linkRepo: repo)
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --filter CancellationDeadlineLinkPersisterTests`

Expected: FAIL — Typen/`Persister` fehlen

- [x] **Step 3: Minimal implementation**

`Sources/ReisenAppCore/CancellationDeadlineSyncPersistPlan.swift`:

```swift
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
```

Domain-Port: `CancellationDeadlineLinkRepository.deleteLinks(ids:)` und `save()` sind vorhanden (`Sources/ReisenDomain/Ports/Repositories.swift`).

- [x] **Step 4: Run tests to verify they pass**

Run: `swift test --filter CancellationDeadlineLinkPersisterTests`

Expected: PASS

- [x] **Step 5: Commit nur auf User-Anweisung**

---

### Task 2: Batch-Commit-Vertrag (Fake, RED→GREEN)

**Files:**
- Create: `Sources/ReisenAppCore/EventKitDeadlineBatchCommit.swift`
- Create: `Tests/ReisenAppCoreTests/EventKitDeadlineBatchCommitTests.swift`

**Interfaces:**
- Consumes: `EventKitBatchCommitting`
- Produces: `EventKitDeadlineBatchCommit.run(itemIDs:store:)` — alle Saves mit `commit: false`, danach genau ein `commit`; leere Liste → kein Commit

- [x] **Step 1: Write the failing test**

```swift
import Testing
@testable import ReisenAppCore

@Suite("EventKitDeadlineBatchCommit")
struct EventKitDeadlineBatchCommitTests {
    final class FakeStore: EventKitBatchCommitting {
        var saveCalls: [(id: String, commit: Bool)] = []
        var commitCount = 0

        func saveItem(id: String, commit: Bool) throws {
            saveCalls.append((id, commit))
        }

        func commit() throws {
            commitCount += 1
        }
    }

    @Test func run_savesWithoutCommitThenSingleCommit() throws {
        let store = FakeStore()
        try EventKitDeadlineBatchCommit.run(itemIDs: ["a", "b", "c"], store: store)
        #expect(store.saveCalls.map(\.commit) == [false, false, false])
        #expect(store.saveCalls.map(\.id) == ["a", "b", "c"])
        #expect(store.commitCount == 1)
    }

    @Test func run_empty_doesNotCommit() throws {
        let store = FakeStore()
        try EventKitDeadlineBatchCommit.run(itemIDs: [], store: store)
        #expect(store.saveCalls.isEmpty)
        #expect(store.commitCount == 0)
    }
}
```

- [x] **Step 2: Run to verify fail**

Run: `swift test --filter EventKitDeadlineBatchCommitTests`

Expected: FAIL — Typen fehlen

- [x] **Step 3: Implement**

```swift
import Foundation

protocol EventKitBatchCommitting: AnyObject {
    func saveItem(id: String, commit: Bool) throws
    func commit() throws
}

enum EventKitDeadlineBatchCommit {
    static func run(itemIDs: [String], store: EventKitBatchCommitting) throws {
        guard !itemIDs.isEmpty else { return }
        for id in itemIDs {
            try store.saveItem(id: id, commit: false)
        }
        try store.commit()
    }
}
```

Im echten Writer (Task 3): dieselbe Semantik direkt auf `EKEventStore` — `save(..., commit: false)` / `remove(..., commit: false)` wo API, dann **ein** `store.commit()`. `EventKitDeadlineBatchCommit` bleibt der isolierte Unit-Test für diese Semantik (kein Produkt-Aufruf nötig). Wenn EventKit für eine Entity keinen `commit: false`-Pfad hat: dokumentierter Einzelfall mit Messung im Spec-Änderungsprotokoll — kein stiller Per-Item-`commit: true` ohne Notiz.

- [x] **Step 4: Tests PASS**

Run: `swift test --filter EventKitDeadlineBatchCommitTests`

Expected: PASS

---

### Task 3: `EventKitDeadlineWriter` Actor + Bridge-Wiring

**Files:**
- Create: `Sources/ReisenAppCore/EventKitDeadlineWriter.swift`
- Modify: `Sources/ReisenAppCore/LocalEventKitBridge.swift` (`syncCancellationDeadlines` und Hilfen: Upsert/Delete ohne `linkRepo` in der EK-Schleife; Access-Helper für Writer teilen oder hierher verschieben)
- Unverändert: `SideEffectPorts.swift`, `LocalSideEffectCoordinator.swift`
- Test: `CancellationDeadlineLinkPersisterTests`, `EventKitDeadlineBatchCommitTests`, `LocalEventKitBridgeDesiredKeysTests`

**Interfaces:**
- Consumes: `EventKitDeadlineWriterRequest` (Sendable Snapshot)
- Produces: `CancellationDeadlineSyncPersistPlan` vom Writer; Bridge wendet Persister an

- [x] **Step 1: Writer-Actor (Kern)**

`Sources/ReisenAppCore/EventKitDeadlineWriter.swift`:

```swift
import Foundation
@preconcurrency import EventKit
import ReisenDomain

struct EventKitDeadlineWriterRequest: Sendable {
    var trips: [Trip]
    var bookings: [Booking]
    var deadlines: [CancellationDeadline]
    var bookingTitles: [UUID: String]
    var eventCalendarTitle: String
    var reminderCalendarTitle: String
    var eventCreateIfMissing: Bool
    var reminderCreateIfMissing: Bool
    var calendarTitleMode: CalendarTitleMode
    var leadTimesDays: [Int]
    /// Bereits auf MainActor geladen: `tripID → links`.
    var existingLinksByTripID: [UUID: [CancellationDeadlineLink]]
}

actor EventKitDeadlineWriter {
    func syncDeadlines(_ request: EventKitDeadlineWriterRequest) async throws -> CancellationDeadlineSyncPersistPlan {
        let clockStart = ContinuousClock.now
        var upserts: [CancellationDeadlineLink] = []
        var deleteIDs: [UUID] = []
        var eventSaveCount = 0
        var reminderSaveCount = 0
        var firstError: Error?
        var failureCount = 0

        let store = EKEventStore()
        let shouldWriteReminders = try await Self.requestAccess(store: store)

        let bookingsByID = Dictionary(uniqueKeysWithValues: request.bookings.map { ($0.id, $0) })
        let eligible = request.deadlines.filter(\.isFreeCancellation)
        let leadTimes = try LeadTimesDays.requireNonEmpty(request.leadTimesDays)
        let calendarDuration: TimeInterval = 60 * 60

        guard !request.trips.isEmpty, !eligible.isEmpty else {
            return CancellationDeadlineSyncPersistPlan(
                upserts: [], deleteIDs: [], eventSaveCount: 0, reminderSaveCount: 0,
                durationMilliseconds: elapsedMs(since: clockStart)
            )
        }

        for trip in request.trips {
            do {
                let tripResult = try Self.syncOneTrip(
                    trip: trip,
                    store: store,
                    shouldWriteReminders: shouldWriteReminders,
                    bookingsByID: bookingsByID,
                    eligibleDeadlines: eligible,
                    leadTimes: leadTimes,
                    calendarDuration: calendarDuration,
                    request: request,
                    existingLinks: request.existingLinksByTripID[trip.id] ?? []
                )
                upserts.append(contentsOf: tripResult.upserts)
                deleteIDs.append(contentsOf: tripResult.deleteIDs)
                eventSaveCount += tripResult.eventSaveCount
                reminderSaveCount += tripResult.reminderSaveCount
            } catch {
                if firstError == nil { firstError = error }
                failureCount += 1
            }
        }

        if eventSaveCount > 0 || reminderSaveCount > 0 || !deleteIDs.isEmpty {
            try store.commit()
        }

        let plan = CancellationDeadlineSyncPersistPlan(
            upserts: upserts,
            deleteIDs: deleteIDs,
            eventSaveCount: eventSaveCount,
            reminderSaveCount: reminderSaveCount,
            durationMilliseconds: elapsedMs(since: clockStart)
        )

        if failureCount > 0, let firstError {
            throw EventKitDeadlinePartialSyncError(plan: plan, cause: firstError)
        }

        return plan
    }

    private struct TripSyncResult: Sendable {
        var upserts: [CancellationDeadlineLink]
        var deleteIDs: [UUID]
        var eventSaveCount: Int
        var reminderSaveCount: Int
    }

    /// Migrierte Hilfen (aus `LocalEventKitBridge`, fileprivate/static am Writer oder shared file):
    /// `ensureCalendar`, `reminderCalendarIfNeeded`, `calendarTitle`, `buildDesiredDeadlineLinks`,
    /// `existingLinksByKey`, `unwantedLinks`, `upsertReminderIfNeeded` (ohne linkRepo; `save(..., commit: false)`).
    private static func syncOneTrip(
        trip: Trip,
        store: EKEventStore,
        shouldWriteReminders: Bool,
        bookingsByID: [UUID: Booking],
        eligibleDeadlines: [CancellationDeadline],
        leadTimes: [Int],
        calendarDuration: TimeInterval,
        request: EventKitDeadlineWriterRequest,
        existingLinks: [CancellationDeadlineLink]
    ) throws -> TripSyncResult {
        var upserts: [CancellationDeadlineLink] = []
        var deleteIDs: [UUID] = []
        var eventSaveCount = 0
        var reminderSaveCount = 0

        let eventCalendar = try ensureCalendar(
            named: calendarTitle(
                for: trip,
                kind: .event,
                calendarTitleMode: request.calendarTitleMode,
                eventCalendarTitle: request.eventCalendarTitle,
                reminderCalendarTitle: request.reminderCalendarTitle
            ),
            kind: .event,
            store: store,
            createIfMissing: request.eventCreateIfMissing
        )
        let reminderCalendar = try reminderCalendarIfNeeded(
            shouldWriteReminders: shouldWriteReminders,
            trip: trip,
            store: store,
            reminderCalendarTitle: request.reminderCalendarTitle,
            calendarTitleMode: request.calendarTitleMode,
            reminderCreateIfMissing: request.reminderCreateIfMissing
        )
        let desiredByKey = buildDesiredDeadlineLinks(
            eligibleDeadlines: eligibleDeadlines,
            bookingsByID: bookingsByID,
            bookingTitles: request.bookingTitles,
            leadTimes: leadTimes,
            trip: trip
        )
        let existingByKey = existingLinksByKey(existingLinks: existingLinks)

        for (_, info) in desiredByKey {
            let existingLink = existingByKey[info.linkKey]
            let existingEvent = existingLink.flatMap { store.event(withIdentifier: $0.eventIdentifier) }
            let event: EKEvent = existingEvent ?? EKEvent(eventStore: store)
            // title/calendar/timeZone/url/start/end/notes/alarms wie bisherige Bridge
            try store.save(event, span: .thisEvent, commit: false)
            eventSaveCount += 1

            let reminderIdentifier = try upsertReminderIfNeeded(
                existingLink: existingLink,
                reminderCalendar: reminderCalendar,
                shouldWriteReminders: shouldWriteReminders,
                store: store,
                info: info,
                commit: false
            )
            if reminderIdentifier != nil { reminderSaveCount += 1 }

            upserts.append(
                CancellationDeadlineLink(
                    id: existingLink?.id ?? UUID(),
                    ownerTripID: trip.id,
                    ownerBookingID: info.booking.id,
                    cancellationDeadlineID: info.deadline.id,
                    leadDays: info.linkKey.leadDays,
                    eventIdentifier: event.eventIdentifier,
                    reminderIdentifier: reminderIdentifier,
                    lastSyncedAt: Date()
                )
            )
        }

        for link in unwantedLinks(existingLinks: existingLinks, desiredKeys: Set(desiredByKey.keys)) {
            if let event = store.event(withIdentifier: link.eventIdentifier) {
                try store.remove(event, span: .thisEvent, commit: false)
            }
            if let reminderIdentifier = link.reminderIdentifier,
               let reminder = store.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder {
                try store.remove(reminder, commit: false)
            }
            deleteIDs.append(link.id)
        }

        return TripSyncResult(
            upserts: upserts,
            deleteIDs: deleteIDs,
            eventSaveCount: eventSaveCount,
            reminderSaveCount: reminderSaveCount
        )
    }

    private static func elapsedMs(since start: ContinuousClock.Instant) -> Int {
        max(0, Int((ContinuousClock.now - start) / .milliseconds(1)))
    }

    private static func requestAccess(store: EKEventStore) async throws -> Bool {
        let eventsGranted = try await store.requestEventAccess()
        guard eventsGranted else {
            // Access-Denied muss `PrivacyOptionalCapability` erkennen:
            // `LocalEventKitBridge.EventKitError` file-level/`nonisolated` machen
            // (oder typealias) und hier `throw LocalEventKitBridge.EventKitError.accessDenied`.
            throw LocalEventKitBridge.EventKitError.accessDenied
        }
        return try await store.requestReminderAccess()
    }
}

// `EventKitAccessError` nicht einführen — Access-Denied bleibt `LocalEventKitBridge.EventKitError`
// (Isolation anpassen). `EKEventStore.requestEventAccess` / `requestReminderAccess`:
// private extension aus Bridge in shared/fileprivate Scope heben.
```

**Implementierungsregel:** Hilfen (`ensureCalendar`, …) im selben Diff aus der Bridge hierher bzw. in shared helpers verschieben, bis der Writer kompiliert. Kein `notWired`-/Stub-Error im Merge. Äußerer `store.commit()` einmal pro Lauf. `remove(..., commit:)`-Overloads gegen SDK prüfen; fehlt `commit: false` → Spec-Notiz + Messung.

- [x] **Step 2: Bridge orchestriert**

`LocalEventKitBridge.syncCancellationDeadlines` (Void):

```swift
public func syncCancellationDeadlines(...) async throws {
    let linkRepo = try requireCancellationDeadlineLinkRepository()
    if trips.isEmpty || deadlines.isEmpty { return }

    let runID = UUID()
    await DiagnosticLogger.shared.record(
        DiagnosticEvent(
            context: DiagnosticContext(runID: runID, providerID: .manual, operation: "eventkit_side_effect"),
            component: "LocalEventKitBridge",
            phase: "cancellation_deadlines",
            event: "sync_started",
            result: .started,
            visibility: .publicDiagnostic
        )
    )

    var existingLinksByTripID: [UUID: [CancellationDeadlineLink]] = [:]
    for trip in trips {
        existingLinksByTripID[trip.id] = try linkRepo.fetchLinks(forTripID: trip.id)
    }

    let request = EventKitDeadlineWriterRequest(
        trips: trips,
        bookings: bookings,
        deadlines: deadlines,
        bookingTitles: bookingTitles,
        eventCalendarTitle: eventCalendarTitle,
        reminderCalendarTitle: reminderCalendarTitle,
        eventCreateIfMissing: eventCreateIfMissing,
        reminderCreateIfMissing: reminderCreateIfMissing,
        calendarTitleMode: calendarTitleMode,
        leadTimesDays: leadTimesDays,
        existingLinksByTripID: existingLinksByTripID
    )

    do {
        let plan = try await EventKitDeadlineWriter().syncDeadlines(request)
        try CancellationDeadlineLinkPersister.apply(plan, linkRepo: linkRepo)
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: DiagnosticContext(runID: runID, providerID: .manual, operation: "eventkit_side_effect"),
                component: "LocalEventKitBridge",
                phase: "cancellation_deadlines",
                event: "sync_finished",
                result: .succeeded,
                durationMilliseconds: plan.durationMilliseconds,
                reason: "events=\(plan.eventSaveCount);reminders=\(plan.reminderSaveCount)",
                visibility: .publicDiagnostic
            )
        )
    } catch {
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: DiagnosticContext(runID: runID, providerID: .manual, operation: "eventkit_side_effect"),
                component: "LocalEventKitBridge",
                phase: "cancellation_deadlines",
                event: "sync_finished",
                result: .failed,
                errorType: String(describing: type(of: error)),
                reason: "eventkit_deadline_sync_failed",
                visibility: .publicDiagnostic
            )
        )
        throw error
    }
}
```

`reason` nur stabile Codes (keine `String(describing: error)`, keine Booking-Titel/URLs). `finalizeCancellationDeadlineSync` entfällt zugunsten Persister + Rethrow.

- [x] **Step 3: Compile + Tests**

Run: `swift test --filter CancellationDeadlineLinkPersisterTests --filter EventKitDeadlineBatchCommitTests --filter LocalEventKitBridgeDesiredKeysTests`

Expected: PASS

Run: `bash ./Scripts/ci-test.sh`

Expected: PASS (Exit 0)

- [ ] **Step 4: Manuelle Acceptance Phase 1** (außerhalb CI; noch offen)

1. `bash ./Scripts/run-app.sh --logging`
2. Viele Stornofristen + „Schreibe Kalender…“
3. UI bedienbar (kein Beachball)
4. Optional neues `.spin`: Main Thread ohne `upsertDesiredDeadlineLinks` → `saveEvent` → `CADXPC`
5. Sync-Log: `sync_started` / `sync_finished` mit Counts

- [x] **Step 5: Commit nur auf User-Anweisung**

---

### Task 4: Timeline-Regression-Hinweis (kein Feature-Diff)

**Files:**
- Reference: [`docs/superpowers/specs/2026-07-21-calendar-timeline-manual-qa.md`](../specs/2026-07-21-calendar-timeline-manual-qa.md)

**Interfaces:** keine neuen

- [x] **Step 1:** Wenn Bridge-Threading Timeline-Methoden berührt: Manual-QA Test 1–3 + Test 6 (Storno) einmal.
- [x] **Step 2:** Keine Timeline-Semantik ändern.

---

### Task 5: Spec-Status Phase 1

**Files:**
- Modify: `docs/superpowers/specs/2026-09-07-macos-beachball-eventkit-swiftdata-design.md`

- [x] **Step 1:** Nach Task-3-Acceptance Status auf `Phase 1 implementiert` setzen.
- [x] **Step 2:** Plan-Link bleibt dieser Datei.

---

### Task 6: Phase 2 — Spin-Analyse → Root Cause (DoD = Spec-Abschnitt)

**Deliverable:** Nur Dokumentation. Kein Produktcode.

**Files:**
- Modify: Spec — Abschnitt `## Phase 2 Root Cause`
- Modify: dieser Plan — kurze Notiz unter Task 7 „RC gelesen: …“ nach Abschluss

**Evidence:**

- `~/Desktop/Voyenna-spins/Voyenna_2026-09-04-205349_MacBook-Pro-RS-10.extract.txt`
- `~/Desktop/Voyenna-spins/Voyenna_2026-09-04-210536_MacBook-Pro-RS-10.extract.txt`
- `~/Desktop/Voyenna-spins/Voyenna_2026-09-04-210623_MacBook-Pro-RS-10.extract.txt`

- [x] **Step 1:** Pro Extrakt Heaviest App-Frames + SwiftData-Anteil notieren.
- [x] **Step 2:** Auf aktuellen Code mappen (`Sources/Reisen/App/ContentView.swift` `handleProviderPrefsRemoteChange`, `ProviderPreferencesImportGate.applyRemoteChange`, CloudKit-Entitlements). Extrakt-Zeilen = Stand 04.09.
- [x] **Step 3:** Eine belegte Kette Trigger → MainActor-Arbeit → HID-Block; ungedeckte Hypothesen verwerfen.
- [x] **Step 4:** In die Spec schreiben (Platzhalter erst beim Ausfüllen ersetzen):

```markdown
## Phase 2 Root Cause

**Datum:** <ISO-Datum der Analyse>
**Extrakte:** <Dateinamen>
**Kette:** <Trigger → Arbeit → HID>
**Beleg:** <Frame → Datei:Zeile aktuell>
**Fix-Richtung:** <konkrete Dateien + Verhalten>
```

- [x] **Step 5:** Task 7 erst starten, wenn Abschnitt vollständig (kein leeres Feld).

---

### Task 7: Phase 2 — Fix laut Root-Cause-Abschnitt

**Status:** implementiert (2026-09-07); manuelle Spin-Acceptance (Step 4) offen.

**Files:** ausschließlich die in Spec `Fix-Richtung` genannten Pfade + passende Tests unter `Tests/`.

**Gate:** Spec `## Phase 2 Root Cause` existiert und nennt Dateien.

Nach Gate (Vorlage — konkrete Asserts/Diffs in Task 6 `Fix-Richtung` spezifizieren, hier nur Ablauf):

- [x] **Step 1:** RED-Test für den in der Spec genannten Vertrag (z. B. Remote-Apply blockiert Main nicht mit **synchronen** Entitlement-/SwiftData-Schwerarbeiten — Formulierung = Spec).
- [x] **Step 2:** Minimaler Fix (Signing-Cache + Prefs-Remote via `Task { @MainActor }`); Prefs-Import behält bestehende Diagnostics; kein neuer Event-Kanal nur für Cache/Deferral; kein Workaround.
- [x] **Step 3:** `bash ./Scripts/ci-test.sh` grün.
- [ ] **Step 4:** Repro; idealerweise neues Spin ohne denselben HID-Cluster (außerhalb CI; noch offen).
- [x] **Step 5:** Spec Status Phase 2 erledigt; Commit nur auf User-Anweisung.

---

## Self-Review

1. **Spec coverage:** Phase-1 Semantik 1–8 (Rev 2 Persist) → Task 1–5; Acceptance → Task 3 Steps 3–4; Phase 2 → Task 6–7.
2. **Placeholders:** Kein `notWired`-Stub; Task-6-Template nur Analyse-Output; Task 7 nach Spec-RC implementiert (manuelle Spin-Acceptance offen).
3. **Typen/Ports:** Void-`CalendarSyncing`; Persist nach EK über Persister in der Bridge; Batch-Semantik Task 2 = Writer-Spiegel; File Map = Architecture = Tasks.
4. **Diagnostics:** Failure-`reason` = stabile Codes `eventkit_deadline_sync_failed` / `eventkit_deadline_sync_partial_failed` (kein Error-String).

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-09-07-macos-beachball-eventkit-swiftdata.md`.

Two execution options:

1. **Subagent-Driven (recommended)** — frischer Subagent pro Task
2. **Inline Execution** — diese Session mit executing-plans

Which approach?
