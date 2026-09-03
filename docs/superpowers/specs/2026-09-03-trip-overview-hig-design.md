# Design: Reise-Übersicht HIG (mittleres Pane)

**Datum:** 2026-09-03
**Status:** Implemented (PR #130)
**Scope:** macOS Trip-Übersicht im mittleren Detail-Pane; iOS Overview-Reihenfolge über dieselbe Presentation-SSOT; Identifier + XCUI; UI-Testing Skip für Crash-Catcher in `AppBootstrap` (Isolation).
**Nicht-Ziele:** Vollständige App-weite HIG-Sanierung; Sidebar-/Menü-/Toolbar-Discoverability aus [2026-07-20-hig-core-ux-review.md](2026-07-20-hig-core-ux-review.md); Kosten-Semantik ([2026-09-01-trip-cost-currency-design.md](2026-09-01-trip-cost-currency-design.md)); neue Domänenfelder außer L10n `trip.notes`; Repo-weites `@AppStorage`-Rewrite.

## Problem

Die macOS-Reise-Übersicht (`TripDetailView.tripOverviewSection`) ist eine kompakte **Einzeilen-Faktenleiste** ohne klare Inhalts-Hierarchie:

1. Keine Überschrift im Content (nur `.navigationTitle`).
2. Horizontale Enge — Truncation statt Lesereihenfolge.
3. Reihenfolge / Gewichtung schwächer als iOS-Section.
4. Caption-lastige Typografie; Notes schwer scannbar.
5. Kein Overview-Identifier.

## Ziele

1. Visuelle Hierarchie: Überschrift → Kontext → Meta → Kosten → Completeness → Notes.
2. Dynamic Type Text Styles.
3. **Eine** Feldreihenfolge-SSOT (`TripOverviewPresentation`) — macOS **und** iOS konsumieren sie (iOS steuert Row-Sichtbarkeit/Reihenfolge darüber, nicht nur manuell).
4. Overview bleibt Header über der Buchungsliste.
5. Identifier + XCUI reach-only; Unit auf Presentation.
6. Trip-Cost unverändert ehrlich.

## Begriffe (SSOT)

| Begriff | Bedeutung |
| --- | --- |
| **Trip-Übersicht / Overview** | Oberer Block im mittleren Pane über der Buchungsliste (macOS) bzw. erste `List`-Section (iOS). |
| **Überschrift** | Reise-Titel als Content-Anker (`.title2` semibold macOS; iOS weiter `.headline` Value). Darüber kleines Section-Label `trip.overview` (`.caption2` tertiary) als XCUI-Anker `tripOverview`. Navigationstitel bleibt parallel (bewusst). |
| **Kontextzeile** | Zielort, wenn nicht leer. |
| **Meta-Zeile** | Zeitraum. |
| **Kostenblock** | `TripCostDisplayText` (unveränderte Semantik). |
| **Completeness-Block** | Fact + Detail-Caption (macOS) / `TripCompletenessOverviewRow` (iOS). |
| **Notes** | Freitext; Label L10n `trip.notes` (DE „Notizen“, EN „Notes“) — **neuer Key**, weil keiner existiert. |
| **TripOverviewPresentation** | Reihenfolge-/Sichtbarkeits-SSOT; beide Plattformen. |
| **TripOverviewMacHeader** | SharedUI macOS-View. |

## Ansatz

**A — Vertikale Hierarchie** (gewählt). Verworfen: Zwei-Spalten-Inspector; nur Font-Bump der HStack.

## Verbindliche Reihenfolge

`TripOverviewPresentation.visibleFields(hasDestination:hasBookings:hasNotes:)`:

1. `title` (immer)
2. `destination` (wenn nicht leer)
3. `period` (immer)
4. `cost` (immer)
5. `completeness` (wenn `hasBookings`)
6. `notes` (wenn nicht leer)

## Typografie (macOS Header)

| Element | Text Style | Farbe |
| --- | --- | --- |
| Titel | `.title2.weight(.semibold)` | primary |
| Ziel | `.headline` | secondary |
| Fact-Label | `.caption` | secondary |
| Fact-Wert | `.body` | primary |
| Cost secondary | `.caption2` | secondary |
| Completeness detail | `.caption` tertiary | |
| Notes | `CopyableValueTextStyle.callout` (neu; SwiftUI `.callout` / AppKit Callout) | secondary, lineLimit 4 |

**Padding:** Parent `TripDetailView`: horizontal **16**, vertikal Overview **12** (Spec-Wert, ersetzt bisheriges 6). Header ohne zusätzliches horizontal Padding.

## UI-Testing Isolation (Crash-Catcher)

`AppBootstrap.init` ruft heute immer `GitHubIssueCrashCatcher.install()` / `flushPending()` auf → `supportDirectoryURL`, ggf. mkdir, `UserDefaults.standard`-Observer.

**Vertrag dieses Features:** `AppBootstrap` speichert den injizierten `UITestingMode` und nutzt ihn konsistent für CrashCatcher (`install`/`flushPending`), `makeReadyState`, Cloud-Observer und Reset. Wenn `skipsSideEffects`: kein Catcher, In-Memory-Container, keine Observer. Production-Default `.fromProcess`. Evidence: Unit-Test mit Hooks + `isStoredInMemoryOnly`; Isolation-Grep.

## Architektur

| Schicht | Verantwortung |
| --- | --- |
| **ReisenSharedUI** | Presentation, MacHeader, Identifier, privater Fact-Helper |
| **Reisen** | Verdrahtung + Cost-Refresh-Hooks am Wrapper |
| **ReiseniOS** | Section baut Rows **nach** `visibleFields` |
| **Domain/L10n** | Key `trip.notes` + xcstrings DE/EN |

## Logging

Layout-only → DiagnosticLogger **begründet entbehrlich**.

## Handler-Trace (`live_app`)

| Journey-Schritt | Handler (Ist) | Side-Effect in Smoke? |
| --- | --- | --- |
| Launch `-UITesting` populated | `ContentView.applyUITestingLaunchSelectionIfNeeded` setzt `selection = .trip(seed)` | nein — Auto-Select |
| Overview sichtbar | `TripDetailView` list-mode + `TripOverviewMacHeader` | nein (Anzeige) |
| Optional: anderer Trip | Sidebar-Click → Outline-Selection (`outlineTripClick` / Selection-Binding) | nur Navigation |

**Smoke v1:** nach `launchPopulated()` **ohne** Extra-Klick (Auto-Select Seed-Trip), dann `waitFor(detail)` + `waitFor(tripOverview)` + `waitFor(tripOverviewTitle)`. `tripOverview` liegt auf dem Section-Label-Text `trip.overview`; Titel-ID am Title-Text. `reisen.detail` nur an Buchungsliste/Empty — nicht am äußeren VStack.

## Identifier

| Element | ID | Regel |
| --- | --- | --- |
| Overview-Section-Label | `reisen.trip.overview` | genau **ein** AX-Treffer; StaticText `trip.overview` im Header |
| Titel | `reisen.trip.overview.title` | genau **ein** Treffer am Title-Text |
| Detail-Pane (Liste/Empty) | `reisen.detail` | am `bookingsList` bzw. Empty-`ContentUnavailableView` — **nicht** am äußeren VStack (sonst überschreibt macOS Kind-Identifier) |

## Isolation-Grep (`live_app`, vollständig)

Vollständiger Grep (kein Stichproben-Listing) vor DoD:

```bash
rg -n '@AppStorage|AppStorage\(|UserDefaults\.standard|fromUserDefaults|supportDirectoryURL|NSWorkspace|EventKit|UNUserNotificationCenter|NotificationCenter\.default|VerifySeed|UITestingLaunch' \
  Sources/Reisen Sources/ReisenSharedUI Sources/ReisenAppCore Apps/ReiseniOS
```

**Baseline (bekannt, Nachbar):** viele `@AppStorage` ohne `store:` in ContentView/TripDetailView/…; `UserDefaults.standard` in AppCore; `supportDirectoryURL` in Persistence/Crash. XCUI: `UITestingIsolationModifier` → `defaultAppStorage(UITestingLaunch.isolatedDefaults)`; In-Memory-Store bei `-UITesting`; Sync/EventKit/Probe unter UI-Testing unterdrückt (siehe [2026-08-30-macos-ui-surface-test-design.md](2026-08-30-macos-ui-surface-test-design.md)).

**Dieses Feature:** keine **neuen** Defaults-/Support-mkdir-Sites im Diff. Jeder neue Treffer braucht `store:`/Skip/Throw oder Spec-Begründung. Bestehende Sites = neighbor.

## UI-Test-Compile

Bestehend erlaubt in `MacUI.swift` / Smoke: `XCTest`, `ReisenAppCore`, `ReisenData`, `ReisenSharedUI`. **Keine** neue Produkt-View (`TripOverviewMacHeader`) in den UI-Test-Runner linken — nur Identifier-Konstanten.

## Schnittstellen

| id | kind | supply | evidence |
| --- | --- | --- | --- |
| trip-overview-entry | entry | Auto-Select Seed-Trip → Overview sichtbar | XCUI Existence ohne Create/Delete |
| trip-overview-order-contract | contract | `TripOverviewPresentation` | Swift Testing |
| trip-overview-ios-order | contract | iOS Section `switch` über `visibleFields` | Presentation-Tests + iOS-Verdrahtung; **pflicht** `bash ./Scripts/ios-test.sh` EXIT 0 |
| trip-overview-neighbor-cost | neighbor | Cost-Text Embed | bestehende Cost-Tests |
| trip-notes-l10n | contract | `trip.notes` DE/EN | L10nKey + xcstrings + Key-Test falls Suite existiert |
| live-app-isolation | contract | UITesting Skip CrashCatcher in AppBootstrap; XCUI Suite/In-Memory; keine neuen Defaults-Sites im Diff | Unit/Assert Skip + Isolation-Grep vollständig |
| live-app-identifiers | contract | IDs eindeutig (count==1) | XCUI Assert matching.count == 1 |
| live-app-assert-vs-act | entry | Smoke Existence-only | MacUISmokeTests Handler-Trace |

## open_gaps

- Advisory Full-Surface-Tour (`macos-ui-review`) → Backlog
- iOS Large-Title / Mac-Header-Visuell 1:1
- HIG-Core Menü/Confirm Rest

## Akzeptanz

1. macOS: Titel `.title2`; Reihenfolge laut Presentation; Padding vertikal 12.
2. Optionale Blöcke entfallen ohne Platzhalter.
3. Cost-Semantik unverändert.
4. iOS konsumiert dieselbe Presentation für Sichtbarkeit/Reihenfolge; Notes mit `trip.notes` wenn vorhanden.
5. XCUI: Overview+Title Existence, je count==1; Isolation-Grep; ci-test + remote UI grün.
