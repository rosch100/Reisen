# HIG Core-UX Discoverability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS-HIG-Discoverability herstellen: Bestätigung für destruktive Aktionen, App-Menü-/Command-Abdeckung der Kernaktionen, Hover-Hints, handlungsfähige Empty States und konsistente Kontextmenüs — gemäß Spec [`docs/superpowers/specs/2026-07-20-hig-core-ux-review.md`](../specs/2026-07-20-hig-core-ux-review.md).

**Architecture:** Bestehende Notification-Bridge (`Notification.Name` in `SidebarSelection.swift` + `.onReceive` in `ContentView`) erweitern für Menü-Commands. Destruktive Aktionen einheitlich über `confirmationDialog` (wie bereits bei manuellem Buchungs-Löschen). Hints/Empty-State-CTAs/Kontextmenüs lokal in den betroffenen Views; keine neuen Domain-Module.

**Tech Stack:** SwiftUI, AppKit (`NSApp`/`NotificationCenter`), macOS 14+, SwiftPM.

## Global Constraints

- Spec-Scope: nur Core UX / Discoverability (Hints, Menüs, Kontextmenüs, Empty-State-CTAs, Destructive Confirm)
- Out of Scope: volles VoiceOver-Audit; iOS/iPadOS-UI; Ausblenden technischer Offset-Felder (Spec L3)
- Keine Workarounds, keine stillen Fallbacks/Dummy-Werte
- SSOT: neue Notification-Namen nur in `SidebarSelection.swift`; Command-Handler zentral in `ContentView` wo möglich
- UI-Verhalten: manuelle Abnahme-Checkliste pro Task (Swift Testing deckt Views hier nicht ab); nach jeder Task `swift build` bzw. App starten
- Deutsche UI-Strings; destruktive Menüpunkte mit Ellipsis `…` wenn Confirm folgt

## File Map

| Datei | Rolle |
|-------|--------|
| `Sources/Reisen/App/SidebarSelection.swift` | SSOT `Notification.Name` für Menü → UI |
| `Sources/Reisen/Reisen.swift` | `.commands`, `StoreFailureView` Confirm |
| `Sources/Reisen/App/ContentView.swift` | Trip-Löschen Confirm, Menü-Handler, Welcome/Open-Bookings Empty CTAs, Sidebar-Kontextmenüs |
| `Sources/Reisen/App/TripDetailView.swift` | Remove-from-trip Confirm, Toolbar-Hints, Empty CTAs, Timeline-Kontextmenü |
| `Sources/Reisen/App/SyncView.swift` | Sync/Browser `.help`, ggf. Sync-Command-Empfang |
| `Sources/Reisen/App/ProviderSidebarRow.swift` | a11y-Label-Fix, optional Provider-Kontextmenü |
| `Sources/Reisen/App/ProviderSyncContainer.swift` | Empty-State CTA bei disabled Provider |
| `Sources/Reisen/App/TripEditorSheet.swift` / `GapEditorSheet.swift` / `AssignBookingsSheet.swift` | `.cancelAction`, Label-Vereinheitlichung |
| `Sources/Reisen/Features/Settings/SettingsView.swift` | Vorlaufzeiten-Footer (L2) |

---

### Task 1: Destructive Confirm — Reise löschen (H1)

**Files:**
- Modify: `Sources/Reisen/App/ContentView.swift`

**Interfaces:**
- Consumes: bestehendes Sidebar-`contextMenu` für `SDTrip`
- Produces: `confirmationDialog` vor `modelContext.delete(trip)`

- [ ] **Step 1: State für Pending-Delete hinzufügen**

In `ContentView` neben den bestehenden `@State`-Properties:

```swift
@State private var tripPendingDelete: SDTrip?
@State private var showTripDeleteConfirmation = false
```

- [ ] **Step 2: Kontextmenü auf Confirm umstellen**

Ersetze den direkten Delete-Block im Reise-`contextMenu` (~Z. 367–372) durch:

```swift
Button(role: .destructive) {
    tripPendingDelete = trip
    showTripDeleteConfirmation = true
} label: {
    Text("Reise löschen…")
}
```

- [ ] **Step 3: `confirmationDialog` am `body`/`sidebar` anhängen**

```swift
.confirmationDialog(
    tripPendingDelete.map { "Reise „\($0.title)“ löschen?" } ?? "Reise löschen?",
    isPresented: $showTripDeleteConfirmation,
    titleVisibility: .visible
) {
    Button("Löschen", role: .destructive) {
        guard let trip = tripPendingDelete else { return }
        if selection == .trip(trip.id) {
            selection = trips.first(where: { $0.id != trip.id }).map { .trip($0.id) }
                ?? .providerSync(.check24)
        }
        modelContext.delete(trip)
        try? modelContext.save()
        tripPendingDelete = nil
    }
    Button("Abbrechen", role: .cancel) {
        tripPendingDelete = nil
    }
} message: {
    Text("Die Reise und zugeordnete Lücken-Metadaten werden entfernt. Buchungen bleiben als offene Buchungen erhalten, sofern sie nicht gelöscht werden.")
}
```

Hinweis: Vor Implementierung kurz prüfen, ob SwiftData-Cascade bei `SDTrip` Buchungen mitlöscht. Wenn Cascade Buchungen löscht, Message anpassen („inkl. zugehöriger Buchungen“) — **keine stille Annahme**. Wahrheit aus `SwiftDataModels` / Relationship-Delete-Rule ablesen und Message exakt setzen.

- [ ] **Step 4: Manuell verifizieren**

1. App starten, Rechtsklick auf Reise → „Reise löschen…“
2. Dialog erscheint; Abbrechen → Reise bleibt
3. Löschen → Reise weg; Selektion nicht auf gelöschter ID hängen

- [ ] **Step 5: Commit**

```bash
git add Sources/Reisen/App/ContentView.swift
git commit -m "$(cat <<'EOF'
fix: confirm before deleting a trip from the sidebar

EOF
)"
```

---

### Task 2: Destructive Confirm — Von Reise entfernen (H2)

**Files:**
- Modify: `Sources/Reisen/App/TripDetailView.swift`

**Interfaces:**
- Consumes: `removeBookingFromTrip(_:fallbackTimelineID:)` und Detail-Links
- Produces: einheitlicher Confirm-Pfad `requestRemoveBookingFromTrip`

- [ ] **Step 1: Pending-State + Request-API**

In `TripDetailView` (neben `pendingManualDeleteBookingID`):

```swift
@State private var pendingRemoveFromTripBookingID: UUID?
@State private var showRemoveFromTripConfirmation = false

private func requestRemoveBookingFromTrip(_ booking: SDBooking) {
    selectTimelineID(booking.id.uuidString)
    pendingRemoveFromTripBookingID = booking.id
    showRemoveFromTripConfirmation = true
}
```

- [ ] **Step 2: Alle Sofort-Removes umleiten**

1. Timeline-`contextMenu` „Von Reise entfernen“ → `requestRemoveBookingFromTrip(booking)` und `role: .destructive`, Label `"Von Reise entfernen…"`
2. `BookingDetailContent` Button (~1169) → Callback `onRequestRemoveFromTrip: (UUID) -> Void` analog zu Delete (oder booking-Objekt); **kein** direktes `booking.trip = nil`
3. `BookingRow.bookingDetailsBody` (~1717) gleich behandeln oder entfernen falls toter Pfad — wenn noch gerendert, Confirm nutzen

`BookingDetailPanel` um Parameter erweitern und von beiden `mode`-Zweigen verdrahten.

- [ ] **Step 3: `confirmationDialog` (list- und detail-Zweig)**

Beide `mode`-Zweige brauchen denselben Dialog (wie bei Manual-Delete bereits dupliziert — vorerst gleiches Pattern beibehalten, kein großes Refactor):

```swift
.confirmationDialog(
    "Buchung von Reise entfernen?",
    isPresented: $showRemoveFromTripConfirmation,
    titleVisibility: .visible
) {
    Button("Entfernen", role: .destructive) {
        guard let id = pendingRemoveFromTripBookingID,
              let booking = trip.bookings.first(where: { $0.id == id }) else { return }
        removeBookingFromTrip(booking, fallbackTimelineID: /* first remaining booking id */)
        pendingRemoveFromTripBookingID = nil
    }
    Button("Abbrechen", role: .cancel) {
        pendingRemoveFromTripBookingID = nil
    }
} message: {
    Text("Die Buchung wird der Reise entzogen und erscheint unter „Offene Buchungen“.")
}
```

`fallbackTimelineID` aus aktueller Timeline wie beim bestehenden Remove berechnen.

- [ ] **Step 4: Manuell verifizieren**

1. Kontextmenü Timeline → Confirm → Entfernen → Buchung unter Offene Buchungen
2. Detail-Link → Abbrechen → Zuordnung bleibt
3. Manual „Löschen…“ weiterhin eigener Dialog

- [ ] **Step 5: Commit**

```bash
git add Sources/Reisen/App/TripDetailView.swift
git commit -m "$(cat <<'EOF'
fix: confirm before removing a booking from a trip

EOF
)"
```

---

### Task 3: Destructive Confirm — Store-Reset (H4)

**Files:**
- Modify: `Sources/Reisen/Reisen.swift` (`StoreFailureView`)

**Interfaces:**
- Consumes: `onReset: () -> Void`
- Produces: Confirm vor `onReset()`

- [ ] **Step 1: Confirm-State in `StoreFailureView`**

```swift
@State private var showResetConfirmation = false

// Button:
Button("Lokale Datenbank zurücksetzen und erneut versuchen…") {
    showResetConfirmation = true
}
.buttonStyle(.borderedProminent)
.confirmationDialog(
    "Lokale Datenbank zurücksetzen?",
    isPresented: $showResetConfirmation,
    titleVisibility: .visible
) {
    Button("Zurücksetzen", role: .destructive, action: onReset)
    Button("Abbrechen", role: .cancel) {}
} message: {
    Text("Alle lokal gespeicherten Reisen und Buchungen werden unwiderruflich gelöscht.")
}
```

- [ ] **Step 2: Manuell verifizieren**

Store-Fehler nur schwer zu provozieren: UI-Preview oder temporär `bootstrap.state = .failed("test")` in DEBUG — **nicht committen**. Alternativ Code-Review + Build.

```bash
cd /Users/roschmac/Entwicklung/Reisen && swift build --target Reisen
```

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/Reisen/Reisen.swift
git commit -m "$(cat <<'EOF'
fix: confirm before resetting the local store

EOF
)"
```

---

### Task 4: App-Menü / Commands für Kernaktionen (H3)

**Files:**
- Modify: `Sources/Reisen/App/SidebarSelection.swift`
- Modify: `Sources/Reisen/Reisen.swift`
- Modify: `Sources/Reisen/App/ContentView.swift`
- Modify: `Sources/Reisen/App/TripDetailView.swift` (Assign/Add Buchung per Notification)
- Modify: `Sources/Reisen/App/SyncView.swift` (optional Sync-current)

**Interfaces:**
- Produces (SSOT in `SidebarSelection.swift`):

```swift
extension Notification.Name {
    static let reisenShowProviderSync = Notification.Name("reisenShowProviderSync")
    static let reisenSyncAllProviders = Notification.Name("reisenSyncAllProviders")
    static let reisenNewTrip = Notification.Name("reisenNewTrip")
    static let reisenAddBooking = Notification.Name("reisenAddBooking")
    static let reisenAssignBookings = Notification.Name("reisenAssignBookings")
    static let reisenEditSelectedTrip = Notification.Name("reisenEditSelectedTrip")
    static let reisenSyncCurrentProvider = Notification.Name("reisenSyncCurrentProvider")
}
```

- [ ] **Step 1: Notification-Namen ergänzen** (wie oben; bestehende zwei behalten)

- [ ] **Step 2: Commands in `Reisen.swift`**

Ersetze `CommandGroup(replacing: .newItem) {}` und erweitere nach `.appInfo`:

```swift
CommandGroup(replacing: .newItem) {
    Button("Neue Reise…") {
        NotificationCenter.default.post(name: .reisenNewTrip, object: nil)
    }
    .keyboardShortcut("n", modifiers: [.command])

    Button("Buchung hinzufügen…") {
        NotificationCenter.default.post(name: .reisenAddBooking, object: nil)
    }
    .keyboardShortcut("n", modifiers: [.command, .shift])

    Button("Buchungen zuordnen…") {
        NotificationCenter.default.post(name: .reisenAssignBookings, object: nil)
    }
}

CommandGroup(after: .appInfo) {
    Button("Provider Sync…") { /* existing */ }
        .keyboardShortcut("1", modifiers: [.command])

    Button("Alle Provider synchronisieren") { /* existing */ }
        .keyboardShortcut("r", modifiers: [.command, .shift])

    Button("Aktuellen Provider synchronisieren") {
        NotificationCenter.default.post(name: .reisenSyncCurrentProvider, object: nil)
    }
    .keyboardShortcut("r", modifiers: [.command])
}

CommandGroup(after: .pasteboard) {
    Button("Reise bearbeiten…") {
        NotificationCenter.default.post(name: .reisenEditSelectedTrip, object: nil)
    }
}
```

Hinweis: ⌘R kollidiert mit SyncView-Toolbar. **Eine** SSOT-Shortcut-Stelle: Command-Menü trägt ⌘R für „aktueller Provider“; Toolbar-Button behält Aktion ohne zweites `.keyboardShortcut`, oder Toolbar behält Shortcut und Menü verzichtet — in diesem Plan: **Menü = SSOT für ⌘R**, SyncView-Toolbar-Shortcut entfernen, Action-Button bleibt.

- [ ] **Step 3: Handler in `ContentView`**

```swift
.onReceive(NotificationCenter.default.publisher(for: .reisenNewTrip)) { _ in
    showCreateTrip = true
}
.onReceive(NotificationCenter.default.publisher(for: .reisenEditSelectedTrip)) { _ in
    if case .trip(let id) = selection, let trip = trips.first(where: { $0.id == id }) {
        tripToEdit = trip
    }
}
.onReceive(NotificationCenter.default.publisher(for: .reisenAddBooking)) { _ in
    if case .trip(let id) = selection, let trip = trips.first(where: { $0.id == id }) {
        startCreateBooking(in: trip)
    }
}
.onReceive(NotificationCenter.default.publisher(for: .reisenAssignBookings)) { _ in
    // Weiterleitung: Notification an TripDetailView oder @State showAssign via shared binding.
    NotificationCenter.default.post(name: .reisenAssignBookingsForTrip, object: selection?.tripID)
}
```

Sauberer: in Task 4 nur Notifications posten, die `TripDetailView` bereits hört:

```swift
// In TripDetailView (mode == .list):
.onReceive(NotificationCenter.default.publisher(for: .reisenAssignBookings)) { _ in
    guard !openBookingsCandidates().isEmpty else { return }
    showAssignBookings = true
}
.onReceive(NotificationCenter.default.publisher(for: .reisenAddBooking)) { _ in
    startCreateBooking(prefillStart: nil, prefillEnd: nil, selectID: selectedTimelineID)
}
```

Dann ContentView-Handler für AddBooking nur, wenn Trip ausgewählt; sonst no-op (Menü-Eintrag darf disabled werden — optional später mit `FocusedValue`).

- [ ] **Step 4: Sync current Provider**

In `SyncView`:

```swift
.onReceive(NotificationCenter.default.publisher(for: .reisenSyncCurrentProvider)) { _ in
    Task { await runSync() }
}
```

Und Toolbar `.keyboardShortcut("r", …)` entfernen (Menü ist SSOT).

- [ ] **Step 5: Manuell verifizieren**

| Shortcut/Menü | Erwartung |
|---------------|-----------|
| ⌘N | Sheet Neue Reise |
| ⇧⌘N | Buchungseditor wenn Trip selektiert |
| Menü „Buchungen zuordnen…“ | Sheet wenn Kandidaten |
| Menü „Reise bearbeiten…“ | TripEditor wenn Trip selektiert |
| ⌘R | Sync aktueller Provider (Sync-UI) |
| ⇧⌘R | Sync alle |

- [ ] **Step 6: Commit**

```bash
git add Sources/Reisen/App/SidebarSelection.swift Sources/Reisen/Reisen.swift \
  Sources/Reisen/App/ContentView.swift Sources/Reisen/App/TripDetailView.swift \
  Sources/Reisen/App/SyncView.swift
git commit -m "$(cat <<'EOF'
feat: expose core trip and sync actions in the app menu

EOF
)"
```

---

### Task 5: Hover-Hints an Toolbar-/Action-Controls (M1, M5, L4)

**Files:**
- Modify: `Sources/Reisen/App/SyncView.swift`
- Modify: `Sources/Reisen/App/TripDetailView.swift`

**Interfaces:**
- Produces: `.help(...)` inkl. disabled-Gründe

- [ ] **Step 1: SyncView Hints**

```swift
// Toolbar sync button:
.help(canSync
    ? "Buchungen dieses Providers jetzt synchronisieren"
    : "Sync nicht möglich — Anmeldung und aktiven Provider prüfen")

// Browser toggle:
.help(isBrowserExpanded ? "Eingebetteten Browser ausblenden" : "Eingebetteten Browser anzeigen")

// Action-Bar „Jetzt synchronisieren“:
.help(canStartSync
    ? "Aktivitäten und Stornofristen dieses Providers lokal aktualisieren"
    : "Sync nicht möglich — Anmeldung und aktiven Provider prüfen")
```

- [ ] **Step 2: TripDetail Toolbar Hints**

```swift
Button("Buchungen zuordnen…") { showAssignBookings = true }
    .disabled(openBookingsCandidates().isEmpty)
    .help(openBookingsCandidates().isEmpty
        ? "Keine offenen Buchungen im Reisezeitraum"
        : "Offene Buchungen dieser Reise zuordnen")

Button("Buchung hinzufügen…") { … }
    .help("Manuelle Buchung für diese Reise anlegen")
```

- [ ] **Step 3: Detail-Action-Hints** (optional aber Spec M1)

In `BookingDetailContent` an Bearbeiten / Löschen… / Von Reise entfernen… jeweils kurzes `.help`.

- [ ] **Step 4: Manuell** — Hover über disabled „Zuordnen“ zeigt Begründung

- [ ] **Step 5: Commit**

```bash
git add Sources/Reisen/App/SyncView.swift Sources/Reisen/App/TripDetailView.swift
git commit -m "$(cat <<'EOF'
feat: add help tooltips to sync and trip toolbar actions

EOF
)"
```

---

### Task 6: Empty-State CTAs (M2)

**Files:**
- Modify: `Sources/Reisen/App/ContentView.swift`
- Modify: `Sources/Reisen/App/TripDetailView.swift`
- Modify: `Sources/Reisen/App/ProviderSyncContainer.swift`
- Modify: `Sources/Reisen/App/SyncView.swift` (disabled Provider empty — CTA optional)

**Interfaces:**
- Produces: `ContentUnavailableView` mit Actions (macOS 14+ `actions:` Trailing Closure bzw. zusätzliche Buttons darunter)

- [ ] **Step 1: Willkommen / keine Selektion**

```swift
ContentUnavailableView {
    Label("Willkommen", systemImage: "airplane")
} description: {
    Text("Wähle eine Reise oder einen Provider in der Seitenleiste.")
} actions: {
    Button("Neue Reise anlegen") { showCreateTrip = true }
    Button("Provider Sync öffnen") { selection = .providerSync(.check24) }
}
```

Falls `actions:` auf Target nicht verfügbar: `VStack { ContentUnavailableView…; Button… }` darunter.

- [ ] **Step 2: Trip ohne Buchungen**

In `TripDetailView` Empty „Keine Buchungen“:

```swift
actions: {
    Button("Buchung hinzufügen…") {
        startCreateBooking(prefillStart: nil, prefillEnd: nil, selectID: nil)
    }
    Button("Buchungen zuordnen…") {
        showAssignBookings = true
    }
    .disabled(openBookingsCandidates().isEmpty)
}
```

- [ ] **Step 3: Offene Buchungen leer**

CTA „Provider Sync öffnen“ → `selection = .providerSync(.check24)` (Binding/Callback von ContentView).

- [ ] **Step 4: Provider deaktiviert**

In `ProviderSyncContainer` / `SyncView`: Beschreibung belassen; optional Button ist schwer ohne Sidebar-Fokus — mind. klarer Text: „Aktiviere den Provider über die Checkbox in der Seitenleiste.“ (bereits vorhanden) — CTA weglassen wenn kein sauberer Hook; Spec erlaubt Fokus-Hinweis.

- [ ] **Step 5: Manuell** — Empty States zeigen Buttons und führen zur Aktion

- [ ] **Step 6: Commit**

```bash
git add Sources/Reisen/App/ContentView.swift Sources/Reisen/App/TripDetailView.swift \
  Sources/Reisen/App/ProviderSyncContainer.swift Sources/Reisen/App/SyncView.swift
git commit -m "$(cat <<'EOF'
feat: add actionable CTAs to primary empty states

EOF
)"
```

---

### Task 7: Kontextmenüs angleichen (M3)

**Files:**
- Modify: `Sources/Reisen/App/ContentView.swift` (Sidebar-Buchung, offene Buchungen)
- Modify: `Sources/Reisen/App/ProviderSidebarRow.swift` (Provider-Kontextmenü)
- Modify: `Sources/Reisen/App/TripDetailView.swift` nur falls nötig für shared Actions

**Interfaces:**
- Consumes: Confirm-APIs aus Task 1–2; Notifications aus Task 4

- [ ] **Step 1: Sidebar-Buchungs-Kontextmenü erweitern**

Neben Bearbeiten / Hinzufügen:

```swift
.contextMenu {
    Button("Bearbeiten") { editBooking(booking, in: trip) }
    Button("Buchung hinzufügen…") { startCreateBooking(in: trip, selectBookingID: booking.id) }
    if let urlString = booking.externalUrl, let url = URL(string: urlString),
       !urlString.hasPrefix("reisen://manual/") {
        Button("Buchung im Browser öffnen") { NSWorkspace.shared.open(url) }
    }
    Button("Von Reise entfernen…", role: .destructive) {
        // Fokus Trip + Post Notification oder State an TripDetailView:
        selection = .trip(trip.id)
        selectedTimelineID = booking.id.uuidString
        NotificationCenter.default.post(
            name: .reisenRequestRemoveBookingFromTrip,
            object: booking.id
        )
    }
    if booking.provider == .manual {
        Button("Löschen…", role: .destructive) {
            NotificationCenter.default.post(
                name: .reisenRequestDeleteManualBooking,
                object: booking.id
            )
        }
    }
}
```

Neue Notifications in `SidebarSelection.swift` ergänzen; `TripDetailView` hört und ruft `requestRemove…` / `requestDelete…` auf. **Kein** direkter Delete ohne Confirm.

- [ ] **Step 2: Offene-Buchungen-Liste Kontextmenü**

```swift
.contextMenu {
    if let urlString = booking.externalUrl, let url = URL(string: urlString),
       !urlString.hasPrefix("reisen://manual/") {
        Button("Buchung im Browser öffnen") { NSWorkspace.shared.open(url) }
    }
    // Zuordnen: wenn genau eine Reise sinnvoll — oder Sheet „Reise wählen“ out of scope;
    // Minimal: Hinweis-Aktion „Zur Reise-Ansicht“ nur wenn User Trip hat:
    Button("In Reise zuordnen…") {
        // Öffne erste passende Trip-Assign oder navigiere zu Trip mit Assign-Sheet
        if let trip = trips.first(where: { /* booking within trip dates */ }) {
            selection = .trip(trip.id)
            NotificationCenter.default.post(name: .reisenAssignBookings, object: nil)
        }
    }
}
```

YAGNI: Wenn „passende Reise“-Heuristik unklar, nur Browser öffnen + „Details anzeigen“ (Selektion setzen). Spec verlangt „Zuordnen zu Reise…“ — nutze existierende Trip-Datums-Filter-Logik aus `TripDetailView.openBookingsCandidates` (als shared helper in ContentView spiegeln oder Notification mit bookingID an Trip).

Minimal-vertretbar: Button öffnet Trip, der die Buchung zeitlich enthält, und postet `reisenAssignBookings` (Sheet mit Vorauswahl später).

- [ ] **Step 3: Provider-Zeile Kontextmenü**

In `ProviderSidebarRow`:

```swift
.contextMenu {
    Button(isEnabled ? "Deaktivieren" : "Aktivieren") { isEnabled.toggle() }
        .disabled(isSyncingThisProvider)
    Button("Sync öffnen") {
        NotificationCenter.default.post(
            name: .reisenShowProviderSync,
            object: providerID
        )
    }
}
```

`reisenShowProviderSync` Handler in ContentView: wenn `object` ein `ProviderID` ist, genau diesen wählen:

```swift
.onReceive(...) { note in
    if let id = note.object as? ProviderID {
        selection = .providerSync(id)
    } else {
        selection = .providerSync(.check24)
    }
}
```

Optional: „Jetzt synchronisieren“ nur wenn `sessionReady` — Hub abfragen.

- [ ] **Step 4: Manuell** — alle neuen Menüpunkte + Confirm-Pfade

- [ ] **Step 5: Commit**

```bash
git add Sources/Reisen/App/SidebarSelection.swift Sources/Reisen/App/ContentView.swift \
  Sources/Reisen/App/ProviderSidebarRow.swift Sources/Reisen/App/TripDetailView.swift \
  Sources/Reisen/Reisen.swift
git commit -m "$(cat <<'EOF'
feat: align context menus for bookings and providers

EOF
)"
```

---

### Task 8: Sheets Cancel-Shortcut + Labels (M4) und a11y-Fix (L1) + Settings-Footer (L2)

**Files:**
- Modify: `Sources/Reisen/App/TripEditorSheet.swift`
- Modify: `Sources/Reisen/App/GapEditorSheet.swift`
- Modify: `Sources/Reisen/App/AssignBookingsSheet.swift`
- Modify: `Sources/Reisen/App/ProviderSidebarRow.swift`
- Modify: `Sources/Reisen/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Sheets**

Überall:

```swift
Button("Abbrechen") { dismiss() }
    .keyboardShortcut(.cancelAction)
```

Labels:
- `TripEditorSheet` / `GapEditorSheet`: Primary-Button von `"OK"` → `"Sichern"`
- `AssignBookingsSheet`: `"Zuordnen"` belassen

- [ ] **Step 2: Provider a11y (L1)**

```swift
.accessibilityLabel(Text(
    isEnabled
        ? "\(providerDisplayName) deaktivieren"
        : "\(providerDisplayName) aktivieren"
))
```

- [ ] **Step 3: Settings Vorlaufzeiten-Footer (L2)**

```swift
Section {
    TextField("Vorläufe in Tagen", text: $leadTimesDaysRaw)
        .textFieldStyle(.roundedBorder)
        .help("Kommagetrennte Tage vor der Stornofrist, z. B. 7,3,1")
    // existing validation Text
} header: {
    Text("Vorlaufzeiten")
} footer: {
    Text("Beispiel: 7,3,1 — Erinnerungen 7, 3 und 1 Tag vor der Frist.")
}
```

- [ ] **Step 4: Build + kurzer UI-Smoke**

```bash
cd /Users/roschmac/Entwicklung/Reisen && swift build --target Reisen
```

Esc schließt Sheets; Checkbox VoiceOver-Label passt.

- [ ] **Step 5: Commit**

```bash
git add Sources/Reisen/App/TripEditorSheet.swift Sources/Reisen/App/GapEditorSheet.swift \
  Sources/Reisen/App/AssignBookingsSheet.swift Sources/Reisen/App/ProviderSidebarRow.swift \
  Sources/Reisen/Features/Settings/SettingsView.swift
git commit -m "$(cat <<'EOF'
fix: standardize sheet shortcuts/labels and provider accessibility

EOF
)"
```

---

### Task 9: Abnahme gegen Spec-Checkliste

**Files:** keine Code-Änderungen (nur Verifikation)

- [ ] **Step 1: Spec-Abnahmekriterien abhaken**

Aus [`2026-07-20-hig-core-ux-review.md`](../specs/2026-07-20-hig-core-ux-review.md):

- [ ] Jede destruktive Persistenz-Aktion hat Confirm (Reise löschen, Von Reise entfernen, Store-Reset, Manual Delete)
- [ ] Kernaktionen ≥2 Findability-Pfade (Matrix: Neue Reise, Sync, Add Booking, Assign)
- [ ] Icon-/Kurzlabel-Controls haben `.help` (Sync toolbar, Trip toolbar, Browser toggle)
- [ ] Primäre Empty States haben ≥1 CTA
- [ ] `CommandGroup(replacing: .newItem)` nicht leer

- [ ] **Step 2: Action-Matrix Stichprobe** (10 Kernaktionen aus Spec manuell)

- [ ] **Step 3: Spec-Dokument Status aktualisieren** (optional kurze „Implemented“-Notiz am Ende der Spec) — nur wenn gewünscht; kein Muss

- [ ] **Step 4: Final commit nur falls Spec-Notiz** — sonst kein Commit

---

## Spec Coverage (Self-Review)

| Spec-Finding | Task |
|--------------|------|
| H1 Reise löschen Confirm | Task 1 |
| H2 Von Reise entfernen Confirm | Task 2 |
| H3 App-Menü / Commands | Task 4 |
| H4 Store-Reset Confirm | Task 3 |
| M1 Hints | Task 5 |
| M2 Empty CTAs | Task 6 |
| M3 Kontextmenüs | Task 7 |
| M4 Sheet shortcuts/labels | Task 8 |
| M5 Toolbar help Assign | Task 5 |
| L1 a11y Provider | Task 8 |
| L2 Settings footer | Task 8 |
| L3 Offset-Felder | Out of Scope |
| L4 Sync-Hierarchie Hints | Task 5 (+ Task 4 Shortcut-SSOT) |

## Out of Scope (bewusst)

- Undo-Stack / `NSUndoManager`
- FocusedValues für disabled Menu Items (kann später folgen)
- VoiceOver-Vollaudit
- iOS UI
- Spec L3 (technische Offset-Anzeige)
