# Design: App-Menü HIG Enable & Sync-Shortcuts

**Datum:** 2026-09-05
**Status:** approved (Plan Menu HIG Conformity)
**Scope:** macOS `ReisenCommands` Enable-States, Sync-Menü-Redundanz, Labels/Shortcuts

## Problem

- „Portal-Sync“ (⌘1) öffnet keine eigene Ansicht — redundant zur Sidebar.
- Sync-/Trip-Menübefehle oft enabled bei No-Op.
- Labels „synchronisieren“ neben Shortcut ⌘R (Refresh-Metapher) waren unehrlich.

## Entscheidungen

| Thema | Entscheidung |
| --- | --- |
| Unmögliche Menübefehle | **disable** (HIG Menu bar), nicht hide |
| Portal-Sync / ⌘1 | aus App-Menü **entfernen**; Keys `menu.provider_sync` / `action.open_sync*` behalten |
| Sync-Labels | DE **aktualisieren** / EN **Refresh** (`menu.sync_*`, `action.sync_all`) |
| Sync-Shortcuts | **⌘R** aktuell, **⇧⌘R** alle — app-spezifisch HIG-ok |
| Logging | Enable-Gating ohne neues `DiagnosticEvent` (begründet entbehrlich); Sync-Läufe unverändert |

## App-spezifische Shortcuts

Menü-Shortcuts gelten nur bei Key-Window Voyenna. Mail-⌘R (Reply) / Finder-⇧⌘R (AirDrop) greifen dann nicht — kein Runtime-Konflikt, kein HIG-Verbot. Residuum: Muskelgedächtnis beim App-Wechsel.

| Variante | Status | Begründung |
| --- | --- | --- |
| ⌘R / ⇧⌘R | **gewählt** | Refresh-Konvention (Safari); Label aktualisieren |
| ⌃⌘R / ⌃⇧⌘R | verworfen | HIG: Control vermeiden; unnötig |
| ⌥⌘R / ⌥⇧⌘R | verworfen | unnötig, sobald app-spezifisch klar ist |

## Enable-Matrix

| Befehl | Enabled wenn |
| --- | --- |
| Alle aktualisieren | `!isSyncing && !syncAllCandidates.isEmpty` |
| Aktuelles Portal aktualisieren | `.providerSync` + `ProviderSyncAvailability.canSync` |
| Neue Buchung… / Reise bearbeiten… | Selection = Trip **und** `selectedTripIDs.count == 1` |
| Buchungen zuordnen… | genau eine Reise + `OpenBookingMatching`-Kandidaten ≠ leer |
| Neue Reise aus Auswahl… | unverändert |
| Browser / Storno | unverändert |

## Help

| Befehl | Enabled | Disabled |
| --- | --- | --- |
| Alle aktualisieren | `action.sync_all_help` | `menu.sync_all_unavailable_help` |
| Aktuelles Portal… | `sync.sync_bookings_help` | `sync.unavailable_help` |
| Zuordnen | `trip.assign_open_help` | `trip.select_trip` / `trip.no_open_in_range` |
| Edit / Neue Buchung | — | `trip.select_trip` |

## Architektur

- `ProviderSyncAvailability` (ReisenAppCore) = Predicate-SSOT für SyncView-Toolbar-`canSync`.
- SyncView setzt `focusedSceneValue(\.providerSyncCanSync, canSync)` — Menü Current = Toolbar 1:1.
- `AppMenuCommandState` + `focusedSceneValue` aus ContentView für Sync-All / Trip-Aktionen.
- Enable-Predicates: `AppMenuCommandAvailability` + `ProviderSyncAvailability` (ReisenAppCore).
- Assign-Kandidaten = dieselbe `OpenBookingMatching`-Logik wie TripDetailView.
- SyncView-Toolbar-Label `sync.sync_bookings` parallel **aktualisieren/Refresh**.

## DoD

- Kein Portal-Sync im App-Menü; ⌘1 nicht an Sync.
- Labels Aktualisieren/Refresh; Shortcuts ⌘R/⇧⌘R.
- Enable = Toolbar; Disabled-Help ≠ Enabled-Help; Edit/Neue Buchung ohne Enabled-Help.
- Unit- + XCUI-Evidence; Spec im Repo.
