# Buchung/Reise löschen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (tasks coupled). Checkbox steps.

**Goal:** HIG-konformes Buchung-Löschen für alle Buchungen und Reise-Löschen mit Option, enthaltene Buchungen mitzulöschen.

**Architecture:** Persistenz-SSOT in `ReisenData`. Copy-SSOT in `ReisenDomain` L10n. Dialog-SSOT in `ReisenSharedUI`. Apps nur verdrahten. Alte Keys `tripDeleteConfirmMessage` / `tripDeleteManualHelp` nach Cutover entfernen.

**Tech Stack:** Swift 6, SwiftData, SwiftUI, Swift Testing, String Catalog.

## Global Constraints

- Spec: [`docs/superpowers/specs/2026-08-28-booking-trip-delete-design.md`](../specs/2026-08-28-booking-trip-delete-design.md)
- TDD: RED = fachlicher Assert-Fail, nicht Compile-Fehler. Neue Signaturen zuerst als Stubs mit altem Verhalten, dann Tests, dann richtige Impl.
- Keine Tombstones; Sync-Restore nur in Copy
- Kein `try?` und kein leeres `catch` auf Delete-Pfaden nach Task 3
- Domain ohne SwiftData
- Nur die stärkste destruktive Dialog-Aktion trägt `role: .destructive`
- Fallback-Titel leere Reise: `L10n.string(.actionDeleteTripConfirm)`
- Worktree: `/Users/roschmac/Entwicklung/Reisen/.worktrees/feat-booking-trip-delete`

## File Map

| Datei | Rolle | Task |
|-------|--------|------|
| `Sources/ReisenData/Persistence/TripDeletion.swift` | Policy + perform | 1 |
| `Sources/ReisenData/Persistence/BookingDeletion.swift` | Buchung löschen | 1 |
| `Tests/ReisenDataTests/TripBookingDeletionTests.swift` | Persistenz + Cascade | 1 |
| `Apps/ReiseniOS/Shared/ReisenTab.swift` | confirmationMessage → L10n (nur Copy-Quelle) | 1 (1 Zeile), 3 (Dialog/Fehler) |
| `Apps/ReiseniOS/Shared/TripDetailIOS.swift` | wie ReisenTab | 1, 3 |
| `Sources/ReisenDomain/Localization/L10nKey.swift` | Keys add/remove | 2 |
| `Sources/ReisenDomain/Resources/Localizable.xcstrings` | de/en | 2 |
| `Sources/ReisenSharedUI/BookingTripActions.swift` | Alarm + Trip-Dialog + Helfer | 2 |
| `Tests/ReisenSharedUITests/BookingTripDeleteCopyTests.swift` | Copy-Helfer | 2 |
| `Sources/Reisen/App/SidebarSelection.swift` | Notification-Rename | 3 |
| `Sources/Reisen/App/ContentView.swift` | Dialoge, Fehler, Guards | 3 |
| `Sources/Reisen/App/TripDetailView.swift` | Dialoge, Selektion, Guards | 3 |
| `Sources/Reisen/App/BookingDetailContent.swift` | Delete alle Provider | 3 |
| `Apps/ReiseniOS/Shared/BookingDetailIOS.swift` | Alarm, dismiss, Fehler | 3 |

---

### Task 1: Persistenz — Policy-Stubs, dann fachliches RED, dann Impl

**Interfaces:**
- `public enum TripDeletionBookingPolicy: Sendable { case keepAsOpen; case deleteContained }`
- `TripDeletion.perform(trip:in:bookings:)` throws
- Überladung `perform(trip:in:)` bleibt in Task 1 und delegiert `keepAsOpen` (UI kompiliert). Task 3 entfernt die Überladung.
- `BookingDeletion.perform(booking:in:)` throws
- `confirmationMessage` bleibt bis Task 3, außer iOS-Message-Zeilen nutzen schon `L10n.string(.tripDeleteConfirmMessage)` damit Data nicht UI-Copy besitzt. Dann `confirmationMessage` in Task 1 löschen.

- [ ] **Step 1: Signaturen mit altem Verhalten (grün kompilierbar, deleteContained noch falsch)**

`TripDeletion.swift` — `deleteContained` absichtlich identisch zu `keepAsOpen` (unlink). `BookingDeletion.swift` — leerer Body, **kein** `context.delete` (nur das ist der Stub; kein Dummy-Save nötig).

```swift
import Foundation
import SwiftData

public enum TripDeletionBookingPolicy: Sendable {
    case keepAsOpen
    case deleteContained
}

public enum TripDeletion {
    public static func perform(trip: SDTrip, in context: ModelContext) throws {
        try perform(trip: trip, in: context, bookings: .keepAsOpen)
    }

    public static func perform(
        trip: SDTrip,
        in context: ModelContext,
        bookings policy: TripDeletionBookingPolicy
    ) throws {
        let assigned = trip.resolvedBookings
        for booking in assigned {
            booking.trip = nil
        }
        _ = policy
        context.delete(trip)
        try context.save()
    }
}
```

```swift
import Foundation
import SwiftData

public enum BookingDeletion {
    public static func perform(booking: SDBooking, in context: ModelContext) throws {
        _ = booking
        _ = context
    }
}
```

In `ReisenTab.swift` und `TripDetailIOS.swift` Message: `Text(L10n.string(.tripDeleteConfirmMessage))` statt `TripDeletion.confirmationMessage`. `confirmationMessage` aus `TripDeletion` löschen.

- [ ] **Step 2: Tests schreiben (vollständige Datei)**

Create `Tests/ReisenDataTests/TripBookingDeletionTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
import ReisenData
import ReisenDomain

@MainActor
private func makeContext() throws -> ModelContext {
    try PersistenceBootstrap.makeInMemoryContainer().mainContext
}

@MainActor
private func makeTrip(in context: ModelContext, title: String = "Italien") -> SDTrip {
    let trip = SDTrip(
        id: UUID(),
        title: title,
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date(timeIntervalSince1970: 1_700_200_000)
    )
    context.insert(trip)
    return trip
}

@MainActor
private func makeBooking(
    in context: ModelContext,
    provider: ProviderID,
    title: String,
    trip: SDTrip?
) -> SDBooking {
    let booking = SDBooking(
        id: UUID(),
        providerRaw: provider.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: title,
        startAt: Date(timeIntervalSince1970: 1_700_050_000),
        endAt: Date(timeIntervalSince1970: 1_700_140_000),
        statusRaw: BookingStatus.confirmed.rawValue,
        trip: trip
    )
    context.insert(booking)
    return booking
}

@MainActor
@Test func tripDeletion_keepAsOpen_unlinksBookingsAndRemovesTrip() throws {
    let context = try makeContext()
    let trip = makeTrip(in: context)
    let booking = makeBooking(in: context, provider: .check24, title: "Hotel Rom", trip: trip)
    try context.save()

    try TripDeletion.perform(trip: trip, in: context, bookings: .keepAsOpen)

    let trips = try context.fetch(FetchDescriptor<SDTrip>())
    let bookings = try context.fetch(FetchDescriptor<SDBooking>())
    #expect(trips.isEmpty)
    #expect(bookings.count == 1)
    #expect(bookings[0].id == booking.id)
    #expect(bookings[0].trip == nil)
}

@MainActor
@Test func tripDeletion_deleteContained_removesTripAndBookings() throws {
    let context = try makeContext()
    let trip = makeTrip(in: context)
    let synced = makeBooking(in: context, provider: .check24, title: "Flug", trip: trip)
    let manual = makeBooking(in: context, provider: .manual, title: "Taxi", trip: trip)
    let deadline = SDCancellationDeadline(
        deadlineAt: Date(timeIntervalSince1970: 1_699_000_000),
        policyText: "free",
        booking: synced
    )
    context.insert(deadline)
    try context.save()
    let syncedID = synced.id
    let manualID = manual.id

    try TripDeletion.perform(trip: trip, in: context, bookings: .deleteContained)

    #expect(try context.fetch(FetchDescriptor<SDTrip>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<SDBooking>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<SDCancellationDeadline>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == syncedID })).isEmpty)
    #expect(try context.fetch(FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == manualID })).isEmpty)
}

@MainActor
@Test func tripDeletion_keepAsOpen_emptyTrip_deletesTrip() throws {
    let context = try makeContext()
    let trip = makeTrip(in: context)
    try context.save()
    try TripDeletion.perform(trip: trip, in: context, bookings: .keepAsOpen)
    #expect(try context.fetch(FetchDescriptor<SDTrip>()).isEmpty)
}

@MainActor
@Test func bookingDeletion_removesBookingChildrenAndLeavesTrip() throws {
    let context = try makeContext()
    let trip = makeTrip(in: context)
    let booking = makeBooking(in: context, provider: .opodo, title: "Hotel", trip: trip)
    let deadline = SDCancellationDeadline(
        deadlineAt: Date(timeIntervalSince1970: 1_699_000_000),
        policyText: "free",
        booking: booking
    )
    context.insert(deadline)
    try context.save()
    let bookingID = booking.id
    let tripID = trip.id

    try BookingDeletion.perform(booking: booking, in: context)

    #expect(try context.fetch(FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == bookingID })).isEmpty)
    #expect(try context.fetch(FetchDescriptor<SDCancellationDeadline>()).isEmpty)
    let trips = try context.fetch(FetchDescriptor<SDTrip>())
    #expect(trips.count == 1)
    #expect(trips[0].id == tripID)
    #expect(trips[0].resolvedBookings.isEmpty)
}
```

- [ ] **Step 3: Tests laufen — fachliches RED**

```bash
cd /Users/roschmac/Entwicklung/Reisen/.worktrees/feat-booking-trip-delete
swift test --filter TripBookingDeletionTests
```

Expected: `tripDeletion_keepAsOpen_*` PASS. `tripDeletion_deleteContained_removesTripAndBookings` FAIL (`bookings` nicht leer / Deadlines nicht leer). `bookingDeletion_removesBookingChildrenAndLeavesTrip` FAIL (Buchung noch da). **Nicht** Compile-Fehler.

- [ ] **Step 4: Richtige Impl**

`TripDeletion.perform(…bookings:)`:

```swift
let assigned = trip.resolvedBookings
switch policy {
case .keepAsOpen:
    for booking in assigned { booking.trip = nil }
case .deleteContained:
    for booking in assigned { context.delete(booking) }
}
context.delete(trip)
try context.save()
```

`BookingDeletion.perform`:

```swift
context.delete(booking)
try context.save()
```

- [ ] **Step 5: Tests grün**

```bash
swift test --filter TripBookingDeletionTests
```

Expected: PASS 4.

- [ ] **Step 6: Commit**

```bash
git add Sources/ReisenData/Persistence/TripDeletion.swift \
  Sources/ReisenData/Persistence/BookingDeletion.swift \
  Tests/ReisenDataTests/TripBookingDeletionTests.swift \
  Apps/ReiseniOS/Shared/ReisenTab.swift \
  Apps/ReiseniOS/Shared/TripDetailIOS.swift
git commit -m "$(cat <<'EOF'
feat: add trip booking-deletion policy and booking deletion SSOT

EOF
)"
```

---

### Task 2: L10n, SharedUI-Helfer/Dialoge, Copy-Tests

**EN verbatim:**

- `booking.delete_confirm_message_synced`: `The booking will be permanently removed from Reisen. After the next provider sync it may reappear if it still exists at the provider.`
- `trip.delete_confirm_message_with_bookings`: `“Delete trip only” keeps the bookings as open bookings. “Delete trip and bookings” permanently removes the contained bookings. Provider bookings may reappear after the next sync.`

Weitere Strings: Spec-Tabelle + Plan File Map Task 2 (de wie Spec).

Neue Keys in `L10nKey` (rawValues wie Spec). **In diesem Task noch nicht** `tripDeleteConfirmMessage` / `tripDeleteManualHelp` löschen (UI Task 3). Nach Task-3-Commit in einem Follow-up-Step derselben Task-3-Datei entfernen — oder am Ende von Task 3.

- [ ] **Step 1: Keys ohne Catalog → L10nTests RED**

Nach `actionDeleteTripConfirm`:

```swift
    case bookingDeleteConfirmTitleNamed = "booking.delete_confirm_title_named"
    case bookingDeleteConfirmMessage = "booking.delete_confirm_message"
    case bookingDeleteConfirmMessageSynced = "booking.delete_confirm_message_synced"
    case bookingDeleteHelp = "booking.delete_help"
```

Nach `tripDeleteConfirmTitleNamed`:

```swift
    case tripDeleteConfirmMessageEmpty = "trip.delete_confirm_message_empty"
    case tripDeleteConfirmMessageWithBookings = "trip.delete_confirm_message_with_bookings"
    case tripDeleteKeepBookings = "trip.delete_keep_bookings"
    case tripDeleteWithBookings = "trip.delete_with_bookings"
```

```bash
swift test --filter l10n_allKeysResolve
```

Expected: FAIL — Key rawValue statt Übersetzung.

- [ ] **Step 2: xcstrings** — JSON wie `action.delete_trip_confirm` (de+en, `state: translated`). Werte:

| Key | de | en |
|-----|----|----|
| booking.delete_confirm_title_named | Buchung „%1$@“ löschen? | Delete booking “%1$@”? |
| booking.delete_confirm_message | Die Buchung wird unwiderruflich aus Reisen entfernt. | The booking will be permanently removed from Reisen. |
| booking.delete_confirm_message_synced | Die Buchung wird unwiderruflich aus Reisen entfernt. Nach dem nächsten Provider-Sync kann sie wieder erscheinen, wenn sie beim Anbieter noch existiert. | The booking will be permanently removed from Reisen. After the next provider sync it may reappear if it still exists at the provider. |
| booking.delete_help | Diese Buchung unwiderruflich löschen | Permanently delete this booking |
| trip.delete_confirm_message_empty | Die Reise und zugeordnete Lücken werden gelöscht. | The trip and its gaps will be deleted. |
| trip.delete_confirm_message_with_bookings | „Nur Reise löschen“ belässt die Buchungen unter Offene Buchungen. „Reise und Buchungen löschen“ entfernt die enthaltenen Buchungen dauerhaft. Anbieter-Buchungen können beim nächsten Sync wieder erscheinen. | “Delete trip only” keeps the bookings as open bookings. “Delete trip and bookings” permanently removes the contained bookings. Provider bookings may reappear after the next sync. |
| trip.delete_keep_bookings | Nur Reise löschen | Delete trip only |
| trip.delete_with_bookings | Reise und Buchungen löschen | Delete trip and bookings |

```bash
swift test --filter l10n_allKeysResolve
```

Expected: PASS.

- [ ] **Step 3: Copy-Helfer-Stubs, dann Tests (fachliches RED), dann richtige Strings**

Zuerst Helfer mit **falschem** Verhalten (kompilierbar): `bookingDeleteMessage` gibt immer `L10n.string(.bookingDeleteConfirmMessage)` zurück (ignoriert `showsSyncRestoreWarning`); `tripDeleteMessage` gibt immer `L10n.string(.tripDeleteConfirmMessageEmpty)` zurück; `tripDeleteTitle(named:)` gibt immer `L10n.string(.actionDeleteTripConfirm)` zurück (ignoriert den Namen).

Dann Tests anlegen. Expected RED (Assert, nicht Compile): synced-Test findet kein `Provider-Sync`; `tripDeleteMessage(bookingCount: 2)` ungleich With-Bookings; `tripDeleteTitle(named: "Italien")` ungleich named format.

Danach Helfer auf Spec-Verhalten umstellen (wie unten). GREEN.

Tests:

Create `Tests/ReisenSharedUITests/BookingTripDeleteCopyTests.swift`:

```swift
import Foundation
import Testing
import ReisenDomain
import ReisenSharedUI

@Test func bookingDeleteMessage_manualHasNoSyncWarning() {
    L10n.locale = Locale(identifier: "de")
    defer { L10n.locale = .current }
    let text = BookingTripActions.bookingDeleteMessage(showsSyncRestoreWarning: false)
    #expect(text == L10n.string(.bookingDeleteConfirmMessage))
    #expect(!text.contains("Provider-Sync"))
}

@Test func bookingDeleteMessage_syncedMentionsProviderSync() {
    L10n.locale = Locale(identifier: "de")
    defer { L10n.locale = .current }
    let text = BookingTripActions.bookingDeleteMessage(showsSyncRestoreWarning: true)
    #expect(text == L10n.string(.bookingDeleteConfirmMessageSynced))
    #expect(text.contains("Provider-Sync"))
}

@Test func tripDeleteMessage_emptyVsWithBookings() {
    L10n.locale = Locale(identifier: "de")
    defer { L10n.locale = .current }
    #expect(BookingTripActions.tripDeleteMessage(bookingCount: 0) == L10n.string(.tripDeleteConfirmMessageEmpty))
    #expect(BookingTripActions.tripDeleteMessage(bookingCount: 2) == L10n.string(.tripDeleteConfirmMessageWithBookings))
}

@Test func tripDeleteTitle_namedAndFallback() {
    L10n.locale = Locale(identifier: "de")
    defer { L10n.locale = .current }
    #expect(BookingTripActions.tripDeleteTitle(named: "Italien") == L10n.format(.tripDeleteConfirmTitleNamed, "Italien"))
    #expect(BookingTripActions.tripDeleteTitle(named: "") == L10n.string(.actionDeleteTripConfirm))
    #expect(BookingTripActions.tripDeleteTitle(named: nil) == L10n.string(.actionDeleteTripConfirm))
}

@Test func tripDeleteDialogUsesSingleDestructiveActionLabel() {
    L10n.locale = Locale(identifier: "de")
    defer { L10n.locale = .current }
    #expect(L10n.string(.tripDeleteWithBookings) == "Reise und Buchungen löschen")
    #expect(L10n.string(.tripDeleteKeepBookings) == "Nur Reise löschen")
}
```

Helfer in `BookingTripActions` (vor den ViewModifier-Änderungen einfügen):

```swift
public enum BookingTripActions {
    public static var removeFromTripTitle: String { L10n.string(.actionRemoveFromTrip) }
    public static var removeFromTripMessage: String { L10n.string(.tripRemoveFromTripHelp) }

    public static func bookingDeleteTitle(named title: String) -> String {
        L10n.format(.bookingDeleteConfirmTitleNamed, title)
    }

    public static func bookingDeleteMessage(showsSyncRestoreWarning: Bool) -> String {
        L10n.string(showsSyncRestoreWarning ? .bookingDeleteConfirmMessageSynced : .bookingDeleteConfirmMessage)
    }

    public static func tripDeleteTitle(named title: String?) -> String {
        guard let title, !title.isEmpty else {
            return L10n.string(.actionDeleteTripConfirm)
        }
        return L10n.format(.tripDeleteConfirmTitleNamed, title)
    }

    public static func tripDeleteMessage(bookingCount: Int) -> String {
        bookingCount == 0
            ? L10n.string(.tripDeleteConfirmMessageEmpty)
            : L10n.string(.tripDeleteConfirmMessageWithBookings)
    }
}
```

Alte `deleteTitle` entfernen erst, wenn Modifier umgestellt sind (gleicher Step).

```bash
swift test --filter BookingTripDeleteCopyTests
```

Nach Stubs: FAIL mit Assert (synced ohne Provider-Sync / named Title falsch). Nach richtiger Impl: PASS.

- [ ] **Step 4: ViewModifier** — vollständiger Ersatz von `BookingTripActions.swift` wie folgt (Remove-From-Trip bleibt confirmationDialog). Altes `bookingDeleteConfirmDialog` entfernen.

Alarm: `.alert(BookingTripActions.bookingDeleteTitle(named:), isPresented:)` Buttons `commonDelete` destructive + `commonCancel`; Message `bookingDeleteMessage(showsSyncRestoreWarning:)`.

Trip-Dialog: `.confirmationDialog(BookingTripActions.tripDeleteTitle(named: tripTitle), isPresented:, titleVisibility: .visible)`. `bookingCount == 0`: `commonDelete` destructive → `onKeepBookings`. Sonst: `tripDeleteWithBookings` destructive → `onDeleteBookings`, dann `tripDeleteKeepBookings` ohne Role → `onKeepBookings`, dann Cancel. Message `tripDeleteMessage(bookingCount:)`.

`bookingTripConfirmDialogs` Parameter: `bookingTitle: String`, `showsSyncRestoreWarning: Bool` plus bestehende Bindings/Closures. Intern Alarm + Remove-Dialog.

Public inits an den Modifiern beibehalten (SharedUI).

Task-3-Aufrufer kompilieren erst nach Task 3. **Diesen Task mit kaputtem App-Target nicht committen**, wenn `swift build` die Apps baut — dann Modifier-API so belassen, dass alte `bookingTripConfirmDialogs` ohne Title **einen Default** bekommt: **kein Default**. Stattdessen Task 2+3 in einem Arbeitsgang bis `swift build` grün, aber **zwei Commits** nur wenn Build zwischen ihnen hält. Praktisch: nach Step 4 sofort Task 3 Steps 1–6, dann zwei logische Commits wenn möglich, sonst ein Commit „dialogs + wire“.

- [ ] **Step 5: `swift test --filter BookingTripDeleteCopyTests` und `l10n_allKeysResolve`** — PASS.

- [ ] **Step 6: Commit** (nur wenn Apps noch bauen; sonst mit Task 3).

```bash
git commit -m "$(cat <<'EOF'
feat: add HIG delete confirmation copy and shared dialogs

EOF
)"
```

---

### Task 3: Wire-up, Fehler-UI, alte Keys/Überladung entfernen

Persistenzfehler: `@State private var persistErrorMessage: String?` + 

```swift
.alert(L10n.string(.tripAssignFailed), isPresented: Binding(
    get: { persistErrorMessage != nil },
    set: { if !$0 { persistErrorMessage = nil } }
)) {
    Button(L10n.string(.commonOk), role: .cancel) { persistErrorMessage = nil }
} message: {
    if let persistErrorMessage { Text(persistErrorMessage) }
}
```

Wenn die View schon `tripAssignFailed`-Alert hat: denselben State wiederverwenden (`assignErrorMessage`). ReisenTab hat keins — Alert hinzufügen. **Kein leeres catch.**

- [ ] **Step 1: `SidebarSelection.swift`**

```swift
static let reisenRequestDeleteBooking = Notification.Name("reisenRequestDeleteBooking")
```

Löschen: `reisenRequestDeleteManualBooking`. Alle `post`/`onReceive` umstellen (`ContentView`, `TripDetailView`).

- [ ] **Step 2: `BookingDetailContent.swift`**

Parameter `onRequestDeleteBooking: ((UUID) -> Void)?`. Button ohne `provider == .manual`. Help `L10n.string(.bookingDeleteHelp)`.

- [ ] **Step 3: `TripDetailView.swift`**

Rename `pendingManualDeleteBookingID` → `pendingDeleteBookingID`, `showManualDeleteConfirmation` → `showDeleteConfirmation`, `requestDeleteManualBooking` → `requestDeleteBooking`, `confirmDeleteManualBooking` → `confirmDeleteBooking`.

Kontextmenü: Delete-Button ohne Manual-Guard.

`confirmDeleteBooking`:

```swift
guard let bookingIDToDelete = pendingDeleteBookingID,
      let bookingToDelete = trip.resolvedBookings.first(where: { $0.id == bookingIDToDelete }) else { return }
do {
    try BookingDeletion.perform(booking: bookingToDelete, in: modelContext)
} catch {
    persistErrorMessage = error.localizedDescription
    pendingDeleteBookingID = nil
    return
}
let newSelection = trip.timelineBookings().first?.id.uuidString
if selectedTimelineID == bookingIDToDelete.uuidString {
    selectedTimelineID = newSelection
}
if case .edit(let editingID) = bookingEditorSession, editingID == bookingIDToDelete {
    bookingEditorSession = nil
}
pendingDeleteBookingID = nil
```

`bookingTripConfirmDialogs(..., bookingTitle: pendingTitle, showsSyncRestoreWarning: pendingProvider != .manual, ...)`.
`pendingTitle`: `trip.resolvedBookings.first(where: { $0.id == pendingDeleteBookingID })?.presentationTitle ?? L10n.string(.editorBooking)`.

- [ ] **Step 4: `ContentView.swift`**

Trip-Block ersetzen durch:

```swift
.tripDeleteConfirmDialog(
    isPresented: $showTripDeleteConfirmation,
    tripTitle: tripPendingDelete?.title ?? "",
    bookingCount: tripPendingDelete?.resolvedBookings.count ?? 0,
    onKeepBookings: { performPendingTripDeletion(.keepAsOpen) },
    onDeleteBookings: { performPendingTripDeletion(.deleteContained) },
    onCancel: { tripPendingDelete = nil }
)
```

```swift
private func performPendingTripDeletion(_ policy: TripDeletionBookingPolicy) {
    guard let trip = tripPendingDelete else { return }
    do {
        try TripDeletion.perform(trip: trip, in: modelContext, bookings: policy)
    } catch {
        persistErrorMessage = error.localizedDescription
        return
    }
    if selection == .trip(trip.id) {
        selection = trips.first(where: { $0.id != trip.id }).map { .trip($0.id) }
            ?? .providerSync(enabledProviderIDs.first ?? .check24)
    }
    tripPendingDelete = nil
}
```

Open-Booking-Detail: `bookingDeleteConfirmAlert` mit `booking.presentationTitle`, `showsSyncRestoreWarning: booking.provider != .manual`, `BookingDeletion.perform` in do/catch (bestehendes Assign-Alert). Sidebar: Delete ohne Manual-Guard; Notification `.reisenRequestDeleteBooking`.

- [ ] **Step 5: `ReisenTab.swift`**

```swift
.tripDeleteConfirmDialog(
    isPresented: $showDeleteConfirm,
    tripTitle: pendingDeleteTrip?.title ?? "",
    bookingCount: pendingDeleteTrip?.resolvedBookings.count ?? 0,
    onKeepBookings: {
        if let trip = pendingDeleteTrip { deleteTrip(trip, bookings: .keepAsOpen) }
    },
    onDeleteBookings: {
        if let trip = pendingDeleteTrip { deleteTrip(trip, bookings: .deleteContained) }
    },
    onCancel: { pendingDeleteTrip = nil }
)
```

```swift
private func deleteTrip(_ trip: SDTrip, bookings policy: TripDeletionBookingPolicy) {
    do {
        try TripDeletion.perform(trip: trip, in: modelContext, bookings: policy)
        if selectedTripID == trip.id { selectedTripID = nil }
    } catch {
        persistErrorMessage = error.localizedDescription
    }
    pendingDeleteTrip = nil
}
```

Leeres `catch` entfernen. Persist-Alert wie oben. Swipe unverändert `allowsFullSwipe: false`.

- [ ] **Step 6: `TripDetailIOS.swift`** — gleiches `tripDeleteConfirmDialog` mit `trip.title` / `trip.resolvedBookings.count`. Erfolg: `dismiss()`. Fehler: Alert, kein dismiss.

- [ ] **Step 7: `BookingDetailIOS.swift`** — Delete ohne Manual-Guard; `bookingTripConfirmDialogs` mit `booking?.presentationTitle ?? ""` und `booking?.provider != .manual`. `deletePendingBooking`: `BookingDeletion.perform`; Erfolg `dismiss()`; Fehler Assign-Alert. Help `.bookingDeleteHelp`.

- [ ] **Step 8: Aufräumen**

- `TripDeletion.perform(trip:in:)`-Überladung löschen; alle Call-Sites nutzen `bookings:`.
- `L10nKey.tripDeleteConfirmMessage`, `tripDeleteManualHelp` und Catalog-Einträge `trip.delete_confirm_message`, `trip.delete_manual_help` löschen.
- `confirmationMessage` darf nicht zurückkommen.

```bash
swift test --filter l10n_allKeysResolve
```

Muss PASS nach Key-Entfernung (Catalog und Enum synchron).

- [ ] **Step 9: Measure**

```bash
bash ./Scripts/ci-build.sh --arch arm64
swift test --filter TripBookingDeletionTests
swift test --filter BookingTripDeleteCopyTests
swift test --filter l10n_allKeysResolve
```

Expected: Exit 0.

- [ ] **Step 10: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: wire HIG booking delete and trip delete booking options

EOF
)"
```

---

## Spec coverage

| Anforderung | Task |
|-------------|------|
| BookingDeletion + Cascade | 1 |
| keepAsOpen / deleteContained | 1 |
| Fachliches RED | 1 Step 3 |
| L10n + EN verbatim | 2 |
| Copy-Helfer-Tests Sync/Empty | 2 |
| Alarm / Bestätigungsdialog | 2–3 |
| Alle Provider, named titles iOS | 3 |
| macOS Timeline-Selektion | 3 Step 3 |
| Persist-Alerts alle Call-Sites | 3 |
| Alte Keys + Überladung weg | 3 Step 8 |

## Type consistency

- `TripDeletionBookingPolicy` / `bookings:`
- `showsSyncRestoreWarning: Bool`
- `reisenRequestDeleteBooking`
- `onRequestDeleteBooking`
