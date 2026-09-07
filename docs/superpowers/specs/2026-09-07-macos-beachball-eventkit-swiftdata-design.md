# macOS Beachball: EventKit + SwiftData — Design

**Datum:** 2026-09-07
**Status:** Phase 1 + Phase 2 implementiert (2026-09-07)
**Plan:** [`docs/superpowers/plans/2026-09-07-macos-beachball-eventkit-swiftdata.md`](../plans/2026-09-07-macos-beachball-eventkit-swiftdata.md)
**Evidenz (außerhalb Repo):** `~/Desktop/Voyenna-spins/` (Index: `README.md`)

## Änderungsprotokoll

### Rev 1 — Conformity

- Status/Plan-Pfad und Evidenz-Header wie Sibling-Specs.
- Grammatik: „synchronen EventKit-XPC-Saves“.
- Phase-1-Scope: Verhaltensänderung nur Deadline-Sync; Timeline-Semantik unverändert (Isolation darf Klasse betreffen).
- Link-Persistenz: bevorzugte Variante DTO → Coordinator (kein Mid-EK-MainActor-Hop). **Superseded by Rev 2.**
- In-Repo-Verwandte als relative Links; Spin-Zeilennummern als Extrakt-Stand gekennzeichnet.

### Rev 2 — Conformity (Plan-SSOT Persist)

- Persist-SSOT: nach EK liefert der Writer ein `CancellationDeadlineSyncPersistPlan`; **`CancellationDeadlineLinkPersister`** schreibt Links auf dem MainActor (Aufruf aus `LocalEventKitBridge` nach `await` Writer). `CalendarSyncing` / Coordinator-Signatur bleiben Void/`await` unverändert — kein Mid-EK-Hop.
- Komponenten-Tabelle und Semantik Punkt 4 an Plan angeglichen.

### Rev 3 — Conformity (Plan-Härtung)

- Failure-Diagnostics: stabiler `reason`-Code, kein Error-`String(describing:)`.
- Writer-Plan ohne `notWired`-Stub; Batch-Unit-Test = Semantik-Spiegel, kein ungenutzter Produkt-Hook.

### Rev 4 — Conformity (Teilfehler + Plan-Status)

- Teilfehler: `EventKitDeadlinePartialSyncError` trägt Persist-Plan; Bridge apply-then-rethrow; stabiler Failure-`reason`.
- Plan-Checkboxes/Status an Spec („Phase 1 + Phase 2 implementiert“) angeglichen.

### Rev 5 — Conformity (SSOT nach Implementation)

- SwiftData-Beispieltext: Ursache festgeschrieben (Verweis Phase-2-RC), nicht mehr „keine Ursache“.
- Plan Task 7 Status + manuelle Acceptance-Checkboxen ehrlich (offen außerhalb CI).

### Rev 6 — Code Review Fixes

- Trip-Isolation: Commit pro erfolgreichem Trip; Store-Replace nach Fehler; IDs nach Commit; `saveCalendar(commit: false)`.
- Bridge: `sync_finished` auch bei Fetch-/Partial-Persist-Fehlern.
- Prefs-Remote: coalesced `ProviderPrefsRemoteChangeScheduler`.

## Phase 2 Root Cause

**Datum:** 2026-09-07
**Extrakte:** `Voyenna_2026-09-04-205349_…`, `210536_…`, `210623_….extract.txt` unter `~/Desktop/Voyenna-spins/`
**Kette:** `.NSPersistentStoreRemoteChange` → `ContentView.handleProviderPrefsRemoteChange` → `ProviderPreferencesImportGate.shouldObserveRemoteChanges` / `shouldSkipCloudKitWait` → `PersistenceBootstrap.isCloudKitEnabledByEnvironment` → wiederholtes `SecCodeCopySigningInformation` (+ SwiftData-Import in `applyRemoteChange`) auf dem Main Thread während HID.
**Beleg:** Extrakt-Hot-Frames `handleProviderPrefsRemoteChange` → `applyRemoteChange` → `shouldSkipCloudKitWait` → `codeSigningEntitlements` / `codeSigningInformation`; parallel SwiftData-Samples. Aktuell: `ContentView.swift` (~Remote-Change-`onReceive`), `ProviderPreferencesImportGate.swift`, `PersistenceBootstrap+CloudKitEnv.swift`.
**Fix-Richtung:**
1. Process-Lifetime-Cache für Code-Signing-Info in `PersistenceBootstrap+CloudKitEnv`.
2. Prefs-Remote-Apply nicht synchron im `onReceive`, sondern `Task { @MainActor in … }` (HID zuerst).
3. Test: wiederholte `isCloudKitEnabledByEnvironment`-Aufrufe stabil.

---

## Problem

Voyenna meldet Beachballs („Slow response to HID event“). System-Spindumps unter `/Library/Logs/DiagnosticReports/Voyenna_*.spin` zeigen zwei Cluster. Gekürzte Extrakte (nicht im Repo): `~/Desktop/Voyenna-spins/`.

| Cluster | Extrakte | Dauer (Header) | Heaviest Main-Thread |
| --- | --- | --- | --- |
| EventKit | 5× `Voyenna_2026-09-06-*.extract.txt` | ~2.3–5.1 s | `LocalEventKitBridge.syncCancellationDeadlines` → `upsertDesiredDeadlineLinks` → `EKEventStore.saveEvent` → CalendarDaemon XPC |
| SwiftData | 3× `Voyenna_2026-09-04-*.extract.txt` | ~3.0–30.2 s | App-Pfad um Provider-Prefs/CloudKit + SwiftData (Symbole teils `???`) — Root Cause Phase 2 |

Beispiel EventKit (Extract `Voyenna_2026-09-06-223312_…`, Duration 5.07 s; Zeilennummern = Extrakt-Stand):

```
LocalEventKitBridge.syncCancellationDeadlines(…)  (LocalEventKitBridge.swift:174)
LocalEventKitBridge.upsertDesiredDeadlineLinks(…) (LocalEventKitBridge.swift:361)
-[EKEventStore saveEvent:span:commit:error:]
-[CADXPCProxyHelper forwardInvocation:]  (CalendarDaemon)
```

Beispiel SwiftData (Extract `Voyenna_2026-09-04-210623_…`, Duration 30.20 s) — Ausgangspunkt Phase 2; **Ursache und Fix:** siehe `## Phase 2 Root Cause` oben:

```
ContentView.handleProviderPrefsRemoteChange()  (ContentView.swift:786 zur Extrakt-Zeit)
ProviderPreferencesImportGate.applyRemoteChange(…)
… PersistenceBootstrap CloudKit/Entitlements …
??? (SwiftData + …)
```

Vollständige Multi‑MB-`.spin`-Dateien gehören nicht ins Git; Spec und Plan zitieren Header/Hot-Frames und verweisen auf die Desktop-Extrakte.

## Erwartete Semantik

### Phase 1 — EventKit (shippable allein)

1. Storno-Deadline-Kalender-/Reminder-Sync (`syncCancellationDeadlines` und zugehörige Upsert/Delete) blockiert den **Main Thread** nicht mit **synchronen** EventKit-XPC-Saves.
2. Pro Sync-Lauf: **ein** `EKEventStore`, ein Writer-Kontext (kein Store-Sharing über Threads).
3. Saves **batchen pro Trip** (`save`/`saveCalendar`/`remove` mit `commit: false`, ein `commit` nach erfolgreichem Trip); fehlgeschlagener Trip → neuer `EKEventStore` (keine Orphan-Commits). Link-IDs erst **nach** Trip-`commit` finalisieren.
4. SwiftData-Link-Persistenz **nach** EK-Erfolg: Writer liefert `CancellationDeadlineSyncPersistPlan`; **`CancellationDeadlineLinkPersister`** schreibt Links auf dem MainActor (von der Bridge nach `await` Writer). Kein MainActor-Hop mitten im EK-Save-Loop. `CalendarSyncing.syncCancellationDeadlines` bleibt Void.
5. `LocalSideEffectCoordinator.maybeScheduleAndSyncCalendars` bleibt asynchron (`try await` Bridge); UI-Status „Schreibe Kalender…“ ok, aber kein synchroner Bridge-Call auf Main.
6. `DiagnosticLogger` / `DiagnosticEvent`: Start, Erfolg, Fehler mit Counts und Dauer; keine PII/Secrets.
7. Teilfehler: nach Batch-`commit` liefert der Writer `EventKitDeadlinePartialSyncError(plan:cause:)`; Bridge wendet `plan` an und wirft `cause` (Diagnostics: `eventkit_deadline_sync_partial_failed`) — keine stillen Fallbacks.
8. **Scope:** Verhaltensänderung und Acceptance nur für den **Deadline**-Pfad. `syncTripTimelineEntries` und verwandte Timeline-Semantik bleiben fachlich unverändert. Actor-/Threading-Umbau der Klasse ist erlaubt, solange Timeline-Verhalten gleich bleibt (kein Timeline-Feature-Scope aus [`2026-07-21-calendar-timeline-eventkit-design.md`](2026-07-21-calendar-timeline-eventkit-design.md)).

### Phase 2 — SwiftData (nach Phase 1, gleiches Doc)

1. Drei 04.09.-Extrakte auswerten: App-Frames oberhalb SwiftData zuordnen, Aufrufer und Trigger festhalten.
2. Root Cause schriftlich in diesem Spec und im Plan ergänzen (kein Fix ohne belegte Ursache).
3. Fix: schwere Persistenz / CloudKit-Wartearbeit vom Main Thread bzw. kleinere Schreibeinheiten — Prinzipien wie Phase 1.
4. Logging Start/Dauer/Fehler; Tests für den neuen Vertrag; Repro ohne HID-Spins dieses Musters.

## Nicht in diesem Fix

- Timeline-Identity-Umbau ([`2026-07-21-calendar-timeline-eventkit-design.md`](2026-07-21-calendar-timeline-eventkit-design.md))
- Spinner-Poll-Log-Flood (#192 / #200)
- Autofill `fill_failed` und WebKit-Catalog-Timeouts
- Debounce-only oder Chunked-`Task.yield`-only als alleinige Lösung
- Einchecken voller `.spin`-Dumps

## Ansatz

**Wahl:** Off-MainActor-Writer + Batch-Commit (Phase 1); SwiftData zweistufig Analyse→Fix (Phase 2).

### Phase 1 — Komponenten

| Einheit | Rolle |
| --- | --- |
| `EventKitDeadlineWriter` | `actor`: Access, Upsert/Delete, Batch-Commit; ein Store pro Lauf; kein SwiftData |
| `LocalEventKitBridge` | Link-Fetch → `await` Writer → `CancellationDeadlineLinkPersister`; Timeline fachlich unverändert |
| `CancellationDeadlineLinkPersister` | MainActor-Link-Upsert/Delete/Save nach EK |
| `LocalSideEffectCoordinator` | unverändert `try await calendarSync.syncCancellationDeadlines(...)` |
| Diagnostics | Sync-Metriken (Anzahl Deadlines/Events/Reminders, ms) |

**Risiken:** EventKit ist nicht thread-safe → strikte Store-Affinität. Reminder- vs. Event-Commit-API in der Implementierung verifizieren. Bei klassenweitem Actor-Umbau: Timeline-Methoden regressionsfrei halten (Tests/manuelle QA laut bestehendem Timeline-Doc, ohne dessen Feature-Scope zu erweitern).

### Phase 2 — Vorgehen

1. Spin-Analyse (Desktop-Extrakte) → Hypothese (Hinweis zur Extrakt-Zeit: `ProviderPreferencesImportGate` / Remote-Change auf Main während SwiftData).
2. Root Cause bestätigen (Code + ggf. neues Spindump nach Repro).
3. Gezielter Fix + Tests + Logging.
4. Acceptance gegen denselben Spin-Cluster.

## Acceptance

**Phase 1**

- Repro mit vielen Storno-Deadlines / „Schreibe Kalender…“: keine neuen Beachballs mit `saveEvent` / `CADXPC` auf dem Main Thread in Spins.
- Diagnostics zeigen Dauer und Counts für den Sync-Lauf.
- Unit-Tests für Isolation-/Batch-/DTO-Vertrag, soweit mockbar; `bash ./Scripts/ci-test.sh` grün.
- Keine fachliche Änderung der Timeline-Sync-Semantik.

**Phase 2**

- Root-Cause-Abschnitt in diesem Spec und im Plan ergänzt.
- Fix gegen belegte Ursache; Repro ohne SwiftData-HID-Spins dieses Musters.
- Tests + Logging wie bei Produktänderungen üblich (`DiagnosticLogger`, passende Target-Tests).

**Evidenz-SSOT für Planung:** dieses Spec + `~/Desktop/Voyenna-spins/*.extract.txt` (Verweise und Zitate, keine Binary-Dumps im Repo).

## Verwandte Docs

- [`2026-07-21-calendar-timeline-eventkit-design.md`](2026-07-21-calendar-timeline-eventkit-design.md) — Feature, nicht Hang-Fix
- [`2026-07-21-calendar-timeline-manual-qa.md`](2026-07-21-calendar-timeline-manual-qa.md) — manuelle QA bei Bridge-Threading-Umbau
- `~/Desktop/Voyenna-spins/README.md` — Index der Extrakte (außerhalb Repo)
