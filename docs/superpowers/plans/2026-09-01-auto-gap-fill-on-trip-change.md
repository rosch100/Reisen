# Auto-Gap-Fill bei Reiseänderungen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nach jeder Trip-Mutation zeitliche und räumliche Lücken erkennen und nur `ProviderID.autoGap`-Buchungen anlegen/anpassen/entfernen.

**Architecture:** Domain-first `ReconcileTripAutoGaps` auf realen Buchungen; zeitlich `GapDetector`, räumlich `SpatialGapDetector` + `PlaceKey`; Match/Suppress über zeitstabilen Key `from|to|role` in Feld `autoGapIdentityKey`; Entry `AutoGapReconcileTrigger.run(tripIDs:)` inkl. Dual-Trip bei Reassign.

**Tech Stack:** Swift, Swift Testing, SwiftData, bestehende Gap-SSOT.

## Global Constraints

- Keine stillen Fallbacks / Dummy-Orte.
- Reconcile ändert/löscht nie Sync- oder Manual-Buchungen; Sync fasst `autoGap` nicht an.
- Completeness/Detect nur `isRealForGapDetect`.
- Identity/Suppress **ohne** Epochs: `fromBookingID|toBookingID|<role>` mit role ∈ {`lodging`,`transport`}.
- **Nicht** `confirmationCode` als Identity missbrauchen — Feld `autoGapIdentityKey: String?`.
- Kein FoundationModels in v1.
- Spec: `docs/superpowers/specs/2026-09-01-auto-gap-fill-on-trip-change-design.md`.
- TDD: Symbole zuerst so anlegen, dass der Test **compiliert** und fachlich RED ist (Assert-Fail), nie Compile-Fail als RED.

---

### Task 1: ProviderID.autoGap + Booking-Filter + autoGapIdentityKey

**Files:**
- Modify: `Sources/ReisenDomain/Entities/ProviderID.swift`
- Modify: `Sources/ReisenDomain/Entities/Booking.swift` (`autoGapIdentityKey: String? = nil` im Init)
- Create: `Sources/ReisenDomain/Entities/Booking+AutoGap.swift`
- Test: `Tests/ReisenDomainTests/AutoGapProviderTests.swift`

**Interfaces:**
- Produces: `ProviderID.autoGap`; `Booking.isAutoGap`; `Booking.isRealForGapDetect`; Property `autoGapIdentityKey`

- [ ] **Step 1: Minimal stubs that compile** — `autoGap` static + Properties returning wrong values if needed, then write tests.

- [ ] **Step 2: Failing tests (Assert-RED)**

```swift
@Test func providerAutoGap_isDistinctFromManual() {
    #expect(ProviderID.autoGap.rawValue == "autoGap")
    #expect(ProviderID.autoGap != .manual)
}

@Test func booking_isRealForGapDetect_excludesAutoAndCancelled() {
    let auto = Booking(provider: .autoGap, bookingType: .hotel, startAt: .now, endAt: .now.addingTimeInterval(3600), autoGapIdentityKey: "a|b|lodging")
    let cancelled = Booking(provider: .manual, bookingType: .hotel, startAt: .now, endAt: .now.addingTimeInterval(3600), status: .cancelled)
    let real = Booking(provider: .manual, bookingType: .hotel, startAt: .now, endAt: .now.addingTimeInterval(3600), status: .confirmed)
    #expect(auto.isAutoGap)
    #expect(auto.autoGapIdentityKey == "a|b|lodging")
    #expect(!auto.isRealForGapDetect)
    #expect(!cancelled.isRealForGapDetect)
    #expect(real.isRealForGapDetect)
}
```

- [ ] **Step 3: Run — expect Assert FAIL if stubs wrong, or implement fully then PASS**

- [ ] **Step 4: Commit** `feat: add autoGap provider and identity field`

---

### Task 2: PlaceKey

**Files:**
- Create: `Sources/ReisenDomain/Services/PlaceKey.swift`
- Test: `Tests/ReisenDomainTests/PlaceKeyTests.swift`

**Interfaces:**
- `PlaceKey.normalize(_ raw: String?) -> String?`
- IATA: exakt 3 Buchstaben nach Trim → uppercase; oder erstes Match `\\(([A-Za-z]{3})\\)` → uppercase; sonst `lowercased()` des Trims; blank → nil

```swift
@Test func placeKey_parentheticalIata() {
    #expect(PlaceKey.normalize("Munich (MUC)") == "MUC")
}
```

- [ ] TDD + Commit `feat: add PlaceKey normalize for spatial gaps`

---

### Task 3: SpatialGapDetector + AutoGapPlanner

**Files:**
- Create: `Sources/ReisenDomain/Services/SpatialGapDetector.swift`
- Create: `Sources/ReisenDomain/Services/AutoGapDesired.swift`
- Create: `Sources/ReisenDomain/Services/AutoGapPlanner.swift`
- Create: `Sources/ReisenDomain/Services/AutoGapIdentity.swift` — `static func key(from:to:role:) -> String`
- Test: `Tests/ReisenDomainTests/SpatialGapDetectorTests.swift`
- Test: `Tests/ReisenDomainTests/AutoGapPlannerTests.swift`

**Interfaces:**
- `enum AutoGapRole: String { case lodging, transport }`
- `AutoGapIdentity.key(from: UUID, to: UUID, role: AutoGapRole) -> String` // `"\(from)|\(to)|\(role.rawValue)"`
- `AutoGapDesired`: identityKey, role, bookingType, startAt, endAt, locationFrom?, locationTo?, fromBookingID, toBookingID
- `AutoGapPlanner.plan(tripStart:tripEnd:bookings:) -> [AutoGapDesired]`
- Ortsextraktion laut Spec-Feldreihenfolge
- Zeitlich: Inter-Gaps via `GapDetector`; Hotel nur wenn Classifier `.lodging` oder `.both`
- Akzeptanz-Test: Flug–Hotel(cancelled)–Flug → lodging Auto zwischen Flügen

- [ ] TDD + Commit `feat: plan auto lodging and transport gaps`

---

### Task 4: Reconcile Diff

**Files:**
- Create: `Sources/ReisenDomain/Services/AutoGapReconcileDiff.swift`
- Create: `Sources/ReisenDomain/UseCases/ReconcileTripAutoGaps.swift`
- Test: `Tests/ReisenDomainTests/ReconcileTripAutoGapsTests.swift`

**Interfaces:**
- Match existing Auto über `booking.autoGapIdentityKey == desired.identityKey` (nicht confirmationCode)
- Tests: insert; **update same key when times change**; delete orphan; skip suppressed; never delete manual

```swift
@Test func reconcile_updatesSameIdentityWhenTimesChange() {
    // existing auto key from|to|lodging with old times; desired same key new times → upserts contains desired, deleteIDs empty
}
```

- [ ] TDD + Commit `feat: reconcile diff for auto-gap bookings`

---

### Task 5: Completeness + L10n

**Files:**
- Modify: `Sources/ReisenDomain/Services/TripCompleteness.swift` — filter `isRealForGapDetect`
- Modify: `Tests/ReisenDomainTests/TripCompletenessTests.swift` — neuen Fall ergänzen, bestehende Asserts nicht schwächen
- L10n Keys für Badge / Provider-Anzeige

- [ ] TDD + Commit `fix: exclude autoGap bookings from trip completeness`

---

### Task 6: SwiftData Feld + Suppress + Apply

**Files:**
- Modify: `Sources/ReisenData/Models/SDBooking.swift` — `autoGapIdentityKey`
- Modify: DomainMapper Booking ↔ SD
- Create: `Sources/ReisenData/Models/SDAutoGapSuppress.swift` (`tripID`, `identityKey`)
- Register in PersistenceBootstrap / schema
- Create: `Sources/ReisenData/Persistence/SwiftDataAutoGapReconciler.swift`
- Test: `Tests/ReisenDataTests/AutoGapReconcilerTests.swift`
- Sync-Nachbar: Assert dass Provider-Delete/`syncProviderIDs` `autoGap` nicht enthält (Test an bestehendem Sync-Filter oder neuer Unit)

- [ ] TDD + Commit `feat: persist auto-gap reconcile and suppress keys`

---

### Task 7: Entry-Hook Dual-Trip

**Files:**
- Create: `Sources/ReisenAppCore/AutoGapReconcileTrigger.swift` — `public static func run(tripIDs: Set<UUID>, …)`
- Modify: `Sources/ReisenData/Persistence/SwiftDataTripRepository.swift` `assignBooking` — vor Assign alten `tripID` lesen, nach Assign `run([old,new].compactMap)`
- Modify: Booking upsert/delete/status-Pfade + Trip-Datums-Upsert + Sync-Assignment (konkrete Call-Sites im Diff suchen und verdrahten)
- Test: Repo- oder Hook-Test — Reassign A→B ruft Trigger mit `{A,B}` auf (Spy)

- [ ] TDD + Commit `feat: reconcile auto gaps after trip mutations`

---

### Task 8: UI Badge, Suppress, Promotion

**Files:**
- SharedUI Booking-Row/Detail Badge wenn `isAutoGap`
- Delete Auto: (1) Suppress-Row schreiben (2) Booking löschen (3) `AutoGapReconcileTrigger.run` — Reihenfolge Pflicht
- Editor save: `provider = .manual`; `autoGapIdentityKey = nil`

- [ ] Tests Promotion/Suppress Domain/Data inkl. „kein Re-Create nach Delete“; XCUI Badge → Spec open_gaps
- [ ] Commit `feat: auto-gap badge, suppress on delete, promote on save`

---

### Task 9: Measure

- [ ] `bash ./Scripts/ci-test.sh` Exit 0
- [ ] `bash ./Scripts/ci-build.sh --arch arm64` Exit 0
- [ ] `bash ./Scripts/ci-coverage-diff.sh origin/master` Gate 5

---

## Spec-Coverage

| Spec | Task |
| --- | --- |
| Zeitstabiler Identity/Suppress | 3, 4 |
| autoGapIdentityKey Feld | 1, 6 |
| Dual-Trip Entry | 7 |
| PlaceKey + (MUC) | 2 |
| Classifier Lodging-Akzeptanz | 3 |
| Completeness | 5 |
| Sync ignore autoGap | 6 |
| AI / Bus / Rand / XCUI / CloudKit-Review | open_gaps |
