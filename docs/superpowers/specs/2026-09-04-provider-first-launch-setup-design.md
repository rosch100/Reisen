# Design: Geführte Erststart-Auswahl der Provider

**Datum:** 2026-09-04 (Aktualisiert 2026-09-05 — Hide-Toggle / Ohne Buchungsportale)
**Status:** approved (Ansatz A — feature-dev full_auto; Gapfill Hide-Option)
**Scope:** macOS + iOS (SharedUI-Sheet); Domain-Gate; Settings-Hide; UITesting; Logging. Baut auf PR #138 (Provider opt-in) und PR #179 (Empty-Continue) auf.

## Problem

Nach PR #138 sind Sync-Portale beim Frischstart opt-in (aus). Die erste Nutzeraktion soll die **Auswahl der abzufragenden Provider** sein. Nutzung **ohne Portale** braucht eine klare HIG-Aktion und eine Settings-Preferenz, sonst bleibt die Erstauswahl nach „Aufschub“ unsichtbar steuerbar.

## Ziele

1. Beim Start (und wenn Hide aus + kein Portal aktiv) erscheint eine **geführte Setup-Oberfläche**.
2. **HIG:** Sheet/Dialog-Metapher, klare Primary/Secondary, VoiceOver-Labels, keine Dead-End-Falle.
3. **Optik:** ruhige, produktnahe Präsentation (Header + Provider-Zeilen); bestehende Voyenna-/System-Chrome nutzen.
4. Continue bestätigt die Auswahl (inkl. 0 Portale = Hide + completed); Secondary **Ohne Buchungsportale** setzt Hide und completed.
5. Settings-Toggle **Erstauswahl der Portale ausblenden** steuert Hide (Key `providerSetupDeferred`).
6. Sidebar-/Settings-Toggles bleiben SSOT für Portal-Aktivierung.
7. UITesting: Populated unterdrückt Sheet; Empty zeigt Sheet (Smoke/Identifier).

## Nicht-Ziele

- Login-/Session-Wizard (bleibt SyncView nach Auswahl).
- Neues Provider-Branding/Asset-Pack (nur vorhandene `displayName` + SF Symbol).
- Erzwingen mindestens eines Providers für immer (Ohne Buchungsportale erlaubt dauerhaft 0).
- iOS-XCUI-Target (existiert nicht) — iOS Host trotzdem verdrahten; Evidence über macOS XCUI + `ios-test.sh`.
- Änderung der Opt-in-Default-Semantik oder Upgrade-Migration aus PR #138.

## Entschiedene Alternativen

| Ansatz | Beschreibung | Urteil |
| --- | --- | --- |
| **A — Modal Setup-Sheet (gewählt)** | SharedUI-Sheet; Multi-Select; Weiter / Ohne Buchungsportale | HIG-üblich; klar geführt; wiederverwendbar macOS/iOS |
| B — Inline Empty-Detail | Setup ersetzt nur ContentUnavailableView | Weniger geführt; leicht zu übersehen |
| C — Mehrstufiger Wizard inkl. Login | Auswahl + Login in einem Flow | YAGNI; vermischt Concerns |

## Begriffe (SSOT)

| Begriff | Bedeutung |
| --- | --- |
| **Setup** | Geführte Auswahl der Sync-Provider |
| **Continue / Weiter** | Persistiert Auswahl; bei ≥1 Portalen Hide aus + completed; bei 0 = wie Ohne Buchungsportale |
| **Ohne Buchungsportale** | Hide an + completed + alle Sync-Portale aus (Identifier bleibt `setup.providers.later`) |
| **Hide / Erstauswahl ausblenden** | Settings-Toggle; Key `reisen_providerSetupDeferred_v1` |
| **Reopen** | Empty-State-CTA „Portale wählen…“, wenn Hide aus und keine Portale aktiv |
| **setupCompleted** | UserDefaults-Flag: Setup abgeschlossen (CloudKit-Prefs) |
| **setupDeferred / Hide** | UserDefaults-Flag: Erstauswahl ausblenden (lokal; nicht CloudKit) |

## Domain-Vertrag

```text
Keys (AppSettingsKeys / SSOT):
  reisen_providerSetupCompleted_v1
  reisen_providerSetupDeferred_v1   // Hide / „Erstauswahl ausblenden“

isInitialSetupHidden(defaults:) -> Bool
setInitialSetupHidden(_:defaults:)

shouldPresent(defaults:syncProviderIDs:) -> Bool
  true iff kein Sync-Portal enabled && !(isInitialSetupHidden && setupCompleted)
  Hide unterdrückt nur nach abgeschlossenem Setup.

markCompleted(defaults:)
markDeferred(defaults:)                 // Alias → setInitialSetupHidden(true)
completeWithoutPortals(syncProviderIDs:defaults:)
  applySelection([]) + setInitialSetupHidden(true) + markCompleted

applySelection(enabledIDs:syncProviderIDs:defaults:)
  setzt providerEnabledKey true für `enabledIDs`, false für übrige `syncProviderIDs`
```

- Defaults-Quelle: `AppSettingsDefaults.current` bzw. injizierte Suite.
- Nach Apply: `ProviderEnabledChange.notify()` im Host (nicht in Domain).
- Upgrade-Heuristik (Bootstrap): mindestens ein Portal aktiv → `setupCompleted=true` (kein Sheet für Bestandskunden mit aktiven Portalen).
- Setup-Flags nur über `AppSettingsDefaults.current` / UITesting-Suite.

## UI-Vertrag (HIG + Optik)

### Präsentation

- SwiftUI `.sheet` (kein Full-Screen-Trap auf macOS).
- Struktur:
  1. Header: SF Symbol `airplane.departure`, Titel, Untertitel.
  2. Liste der `ProviderID.syncProviderIDs` mit Toggle; optional Caption `settingsAppInstalled`.
  3. Footer-Actions: **Weiter** (`.borderedProminent`, immer aktiv) und **Ohne Buchungsportale** (`.bordered` / cancel-ähnlich).
- macOS: `.presentationSizing(.fitted)`; iOS: Standard-Sheet + Drag-Indicator.

### Copy (L10n de/en)

| Key | DE | EN |
| --- | --- | --- |
| `setup.providers.title` | Buchungsportale wählen | Choose Booking Portals |
| `setup.providers.subtitle` | Wähle die Portale… | Choose the portals… |
| `setup.providers.continue` | Weiter | Continue |
| `setup.providers.later` | Ohne Buchungsportale | Without Booking Portals |
| `setup.providers.reopen` | Portale wählen… | Choose Portals… |
| `settings.hide_provider_setup` | Erstauswahl der Portale ausblenden | Hide Portal Setup on Launch |
| `settings.hide_provider_setup_footer` | Wenn ausgeschaltet und kein Portal aktiv ist, erscheint die Auswahl beim Start. | When off and no portal is enabled, setup appears on launch. |

### Accessibility / Identifier

| Identifier | Element |
| --- | --- |
| `setup.providers.sheet` | Sheet-Root |
| `setup.providers.toggle.<rawValue>` | Toggle pro Provider |
| `setup.providers.continue` | Weiter |
| `setup.providers.later` | Ohne Buchungsportale |
| `setup.providers.reopen` | Empty-State-CTA |
| `reisen.settings.hide-provider-setup` | Settings-Hide-Toggle |

### Host-Verhalten

**macOS `ContentView` / iOS `RootTabView`:**

- Nach Bootstrap: Import-Gate, dann wenn `shouldPresent` → Sheet (`reason=fresh_launch`).
- Bei `ProviderEnabledChange` (Sidebar-/Settings-Enable **oder** Hide-Toggle): wenn `shouldPresent` → Sheet (`reason=no_enabled_providers`). Nicht aus `scenePhase` allein.
- Continue ≥1: `applySelection` → Hide aus → notify → `markCompleted` → Prefs-Export → dismiss → Sync/Selection.
- Continue 0 / Ohne Buchungsportale: `completeWithoutPortals` → notify → Prefs-Export → dismiss.
- Empty-State Reopen: wenn `!isInitialSetupHidden && enabledProviderIDs.isEmpty`.

**Settings (`ProviderEnabledSettingsSection`):** eigene Section für Hide-Toggle (Footer Hide-Text); Portal-Toggles darunter mit `sync.enable_portals_hint`.

**iOS Reopen:** `SyncTab.emptyProviders` gleicher Reopen-CTA.

### CloudKit Import-Gate

Unverändert (siehe iCloud-Prefs-Spec): Wait auf Import; synced `setupCompleted` → skip; Timeout → lokales Setup; Late-Import dismiss. Hide/`setupDeferred` **nicht** nach CloudKit.

## UITesting / Isolation (`live_app`)

| Mode | Verhalten |
| --- | --- |
| Populated (`-UITesting`) | `seedProviderSetupIfNeeded`: `setupCompleted=true` **und** Hide an → kein Sheet |
| Empty (`-UITestingEmpty`) | Flags ungesetzt → Sheet auto sichtbar |

### Empty-Launch-Vertrag

1. `MacUI.waitForWindow`: Sheet-Existence akzeptiert.
2. Smoke `testEmptyLaunchShowsProviderSetupSheet`: Reach-only Sheet.
3. Empty-Smokes: Dismiss via `setup.providers.later` → `completeWithoutPortals` (Hide + completed, kein Reopen).
4. Smoke `testEmptyLaunchWithoutPortalsDismissesSetup` / Empty-Continue; Settings-Hide-Toggle Existence.
5. Populated: Sheet-Count `0`.

## Logging

| event | result | reason Beispiele |
| --- | --- | --- |
| `provider_setup_presented` | started | `fresh_launch` / `no_enabled_providers` / `reopen` |
| `provider_setup_completed` | succeeded | `continue_count_<n>` |
| `provider_setup_deferred` | cancelled | `without_portals` |
| `provider_setup_skipped` | skipped | `icloud_prefs` / `icloud_prefs_late` |

## Tests

1. Domain: `shouldPresent` (Hide nur mit completed; Enables); `completeWithoutPortals`; Hide-Toggle-Semantik.
2. Bootstrap/UITesting: Populated seed completed+Hide; Empty nicht.
3. Upgrade-Heuristik: aktive Portale → completed.
4. macOS XCUI: Empty Sheet; Ohne-Portale-Dismiss; Settings-Hide-Toggle; Populated ohne Sheet.
5. Identifier in SharedUI SSOT.

## open_gaps (bewusst)

- Kein iOS-XCUI: Evidence macOS-XCUI + iOS Compile.
- Keine Screenshot-Regression-Suite.
- Geräteübergreifende Prefs: iCloud-Prefs-Spec (Hide lokal).

## Akzeptanz

1. Frische Defaults → Sheet erscheint.
2. Weiter mit ≥1 Provider → Portale aktiv, Sheet weg.
3. Weiter mit 0 / Ohne Buchungsportale → Hide an, completed, kein Reopen, App nutzbar.
4. Hide aus + kein Portal aktiv → Sheet (Start **oder** nach Enable/Hide-Notify).
5. Hide an **und** setupCompleted → kein Auto-Sheet. Hide ohne completed (Settings vor Abschluss oder Import von `setupCompleted=false`) → Sheet.
6. Bestandskunden mit aktiven Portalen → kein Sheet.
7. Populated-XCUI ohne Sheet; Empty zeigt Sheet.
8. Synced `setupCompleted` (CloudKit) → kein Sheet; Late-Import dismiss.
9. `scenePhase` allein öffnet das Sheet nicht.
