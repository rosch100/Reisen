# Design: Geführte Erststart-Auswahl der Provider

**Datum:** 2026-09-04
**Status:** approved (Ansatz A — feature-dev full_auto)
**Scope:** macOS + iOS (SharedUI-Sheet); Domain-Gate; UITesting; Logging. Baut auf PR #138 (Provider opt-in) auf.

## Problem

Nach PR #138 sind Sync-Portale beim Frischstart opt-in (aus). Die erste Nutzeraktion soll die **Auswahl der abzufragenden Provider** sein. Heute gibt es dafür **keine geführte UI** — nur Sidebar-/Settings-Checkboxen und einen Hinweistext. Das ist weder Erststart-geführt noch HIG-klar.

## Ziele

1. Beim Erststart erscheint eine **geführte Setup-Oberfläche** zur Provider-Auswahl.
2. **HIG:** Sheet/Dialog-Metapher, klare Primary/Secondary, VoiceOver-Labels, keine Dead-End-Falle.
3. **Optik:** ruhige, produktnahe Präsentation (Header + Provider-Zeilen), keine generische „AI-purple“-Optik; bestehende Voyenna-/System-Chrome nutzen.
4. Continue aktiviert ≥1 Portal und beendet Setup; „Später“ verschiebt ohne Portale zu aktivieren.
5. Sidebar-/Settings-Toggles bleiben SSOT für spätere Änderungen.
6. UITesting: Populated unterdrückt Sheet; Empty zeigt Sheet (Smoke/Identifier).

## Nicht-Ziele

- Login-/Session-Wizard (bleibt SyncView nach Auswahl).
- Neues Provider-Branding/Asset-Pack (nur vorhandene `displayName` + SF Symbol).
- Erzwingen mindestens eines Providers für immer (Later erlaubt Aufschub).
- iOS-XCUI-Target (existiert nicht) — iOS Host trotzdem verdrahten; Evidence über macOS XCUI + `ios-test.sh`.
- Änderung der Opt-in-Default-Semantik oder Upgrade-Migration aus PR #138.

## Entschiedene Alternativen

| Ansatz | Beschreibung | Urteil |
| --- | --- | --- |
| **A — Modal Setup-Sheet (gewählt)** | SharedUI-Sheet beim Cold Launch; Multi-Select; Weiter / Später | HIG-üblich für Setup; klar geführt; wiederverwendbar macOS/iOS |
| B — Inline Empty-Detail | Setup ersetzt nur ContentUnavailableView | Weniger geführt; leicht zu übersehen; Sidebar ablenkend |
| C — Mehrstufiger Wizard inkl. Login | Auswahl + Login in einem Flow | YAGNI; vermischt Concerns; bricht SyncView-SSOT |

## Begriffe (SSOT)

| Begriff | Bedeutung |
| --- | --- |
| **Setup** | Einmalige Erstauswahl der Sync-Provider |
| **Continue / Weiter** | Persistiert Auswahl (≥1 aktiv), markiert Setup abgeschlossen |
| **Later / Später** | Schließt Sheet ohne Aktivierung; kein Auto-Show mehr bis manuelles Reopen |
| **Reopen** | Empty-State-CTA „Portale wählen…“, wenn Setup nicht completed und keine Portale aktiv |
| **setupCompleted** | UserDefaults-Flag: Weiter wurde bestätigt |
| **setupDeferred** | UserDefaults-Flag: Später gewählt (Auto-Present aus) |

## Domain-Vertrag

Neue Domain-Unit (pure, testbar), z. B. `ProviderFirstLaunchSetup`:

```text
Keys (AppSettingsKeys / SSOT):
  reisen_providerSetupCompleted_v1
  reisen_providerSetupDeferred_v1

shouldPresent(defaults:) -> Bool
  true iff !completed && !deferred

markCompleted(defaults:)
markDeferred(defaults:)

applySelection(enabledIDs:syncProviderIDs:defaults:)
  setzt providerEnabledKey true für `enabledIDs`, false für übrige `syncProviderIDs`
  (explizit, kein stiller Default)
```

- Defaults-Quelle: `AppSettingsDefaults.current` (wie PR #138).
- Nach Apply: `ProviderEnabledChange.notify()` im Host (nicht in Domain).
- Upgrade-Installationen mit bereits materialisierten `providerEnabled_*` (PR #138 Migration): wenn **mindestens ein** Portal aktiv **oder** irgendein `reisen_providerEnabled_*` existiert → Bootstrap setzt `setupCompleted=true` (kein Sheet für Bestandskunden). Frischinstall ohne Keys → Sheet.
- Setup-Flags lesen/schreiben **nur** über `AppSettingsDefaults.current` bzw. injizierte Suite — keine neuen `UserDefaults.standard`-Call-Sites für Setup-Keys.

## UI-Vertrag (HIG + Optik)

### Präsentation

- SwiftUI `.sheet` (kein Full-Screen-Trap auf macOS).
- Struktur:
  1. Header: SF Symbol `airplane.departure` (oder App-Icon Asset falls ohnehin Shared), Titel, ein kurzer Untertitel.
  2. Liste/Form der `ProviderID.syncProviderIDs` mit Toggle (Name = `displayName`); optional Caption wenn Native-App installiert (`settingsAppInstalled`) — gleiches Signal wie Settings.
  3. Footer-Actions: **Weiter** (`.borderedProminent`, disabled wenn 0 gewählt) und **Später** (`.bordered` / cancel-ähnlich).
- macOS: `.presentationSizing(.fitted)` analog anderer Sheets wo passend; sinnvolle Min-Breite.
- iOS: Standard-Sheet; Drag-Indicator sichtbar.
- Farben/Typo: System Semantik (`.primary` / `.secondary`); **kein** lila Gradient, kein Glow, keine Pill-Cluster.

### Copy (L10n de/en, neue Keys)

| Key (Vorschlag) | DE | EN |
| --- | --- | --- |
| `setup.providers.title` | Buchungsportale wählen | Choose Booking Portals |
| `setup.providers.subtitle` | Wähle die Portale, die Voyenna synchronisieren soll. Du kannst das später jederzeit ändern. | Choose the portals Voyenna should sync. You can change this anytime. |
| `setup.providers.continue` | Weiter | Continue |
| `setup.providers.later` | Später | Later |
| `setup.providers.reopen` | Portale wählen… | Choose Portals… |

Ellipsis bei Reopen: **ja** (öffnet Sheet).

### Accessibility / Identifier

| Identifier | Element |
| --- | --- |
| `setup.providers.sheet` | Sheet-Root |
| `setup.providers.toggle.<rawValue>` | Toggle pro Provider |
| `setup.providers.continue` | Weiter |
| `setup.providers.later` | Später |
| `setup.providers.reopen` | Empty-State-CTA |

Jede ID höchstens **ein** Element im erwarteten Tree.

### Host-Verhalten

**macOS `ContentView`:**

- Nach Bootstrap / onAppear: wenn `shouldPresent` → Sheet.
- Continue: `applySelection` → notify → `markCompleted` → dismiss → `selectFirstEnabledProviderSyncIfAvailable()`.
- Later: `markDeferred` → dismiss; Selection bleibt nil / Empty-State.
- Empty-State: wenn `!setupCompleted && enabledProviderIDs.isEmpty` → Button Reopen (neben/statt nur Disabled-Hint).

**iOS `RootTabView`:** gleiches Sheet; Continue wechselt optional auf Sync-Tab wenn Provider-Sync verfügbar.

**iOS Reopen:** `SyncTab.emptyProviders` erhält denselben Reopen-CTA (`setup.providers.reopen`), der das Sheet erneut präsentiert (Akzeptanz #3 gilt macOS **und** iOS Host, Evidence macOS-XCUI + iOS Compile).

### Session-Probe

Solange Setup präsentiert wird: keine erzwungene Login-Selection (bereits durch opt-in leer). Probe darf laufen, Selection-Initialisierung bleibt wie PR #138 (`selection = nil` ohne enabled).

## UITesting / Isolation (`live_app`)

| Mode | Verhalten |
| --- | --- |
| Populated (`-UITesting`) | `seedProviderSetupIfNeeded`: `setupCompleted=true` (+ bestehende Provider-Enable-Seeds) → **kein** Sheet |
| Empty (`-UITestingEmpty`) | Flags ungesetzt → Sheet **auto sichtbar** |

### Empty-Launch-Vertrag (Ist-Navigation, verbindlich)

1. `MacUI.waitForWindow`: akzeptiert zusätzlich Existence von `setup.providers.sheet` (Fenster gilt als bereit).
2. **Dedizierter Smoke** `testEmptyLaunchShowsProviderSetupSheet`: nur `waitFor(setup.providers.sheet)` — **kein** Continue-/Later-Tap (Assert vs Act / Reach-only).
3. **Bestehende Empty-Smokes** (`createTripViaEmptyCTA`, ReviewTour Empty → `emptyState`): vor Nutzung von `emptyState` / `emptyStateNewTrip` **Dismiss** via Later-Tap (`setup.providers.later`) — Handler = `markDeferred` only (keine Provider-Aktivierung, kein Login-Disclosure). Page-Object-Helper z. B. `dismissProviderSetupIfPresent()`.
4. **Kein** Continue in ReviewTour/Empty-Create — Continue wäre Produktions-Handoff (Enable + ggf. Sync-Pfad / Disclosure).
5. Populated: Assert Sheet-Count `0` für `setup.providers.sheet`.

### Isolation-Grep-Baseline (Scope dieses Features)

- **In Scope / Fail:** neue Setup-Keys und Apply-Pfad nur `AppSettingsDefaults.current` oder UITesting-Suite; Host/`@AppStorage` nur unter `defaultAppStorage(isolatedDefaults)` wenn UITesting aktiv.
- **Residual (nicht dieses Feature, nicht Continue-XCUI):** bestehende `UserDefaults.standard`-Sites (`ProviderLoginDisclosure.accept`, Teile `SyncTab`, CrashCatcher). Continue-XCUI, der Disclosure-Login auslöst, ist **v1 out of scope**; Empty-Dismiss bleibt Later-only.

Compile-Units: XCUI importiert weiter `ReisenSharedUI` Identifier-SSOT (bestehende Grenze); keine neuen SharedUI-SwiftUI-Types in den Test-Runner linken außer Identifier-Konstanten.

Prozess-Hooks: `AppSettingsDefaults.installOverride` + `UITestingLaunch.isolatedDefaults` nur Bootstrap/UITesting — keine unsynchronisierte Parallel-Mutation in Unit-Tests (Suite pro Test / removePersistentDomain wie bestehende Tests).

## Logging

`DiagnosticLogger` Events (component z. B. `ProviderFirstLaunchSetup`):

| event | result | reason Beispiele |
| --- | --- | --- |
| `provider_setup_presented` | started | `fresh_launch` |
| `provider_setup_completed` | succeeded | `continue_count_<n>` (nur Anzahl, keine Provider-Namen als PII-Risiko — raw IDs ok als stabile Machine-Strings) |
| `provider_setup_deferred` | cancelled | `later` |

## Tests

1. Domain: `shouldPresent` Matrix (completed/deferred/combos); `applySelection` setzt Keys explizit.
2. Bootstrap/UITesting: Populated seed completed; Empty nicht.
3. Upgrade-Heuristik: vorhandene `providerEnabled_*` → completed ohne Sheet.
4. macOS XCUI: Empty Smoke Existence Sheet; Populated Smoke bricht nicht (kein Sheet).
5. Identifier in SharedUI SSOT.

## open_gaps (bewusst)

- Kein iOS-XCUI: iOS-Optik manuell / `ios-test.sh` Compile; Identifier trotzdem gesetzt.
- Keine Screenshot-Regression-Suite für Optik; HIG-Review optional via `macos-ui-review.sh` nach Implementierung.

## Akzeptanz

1. Frische Defaults → Sheet erscheint vor sinnvoller Sync-Arbeit.
2. Weiter mit ≥1 Provider → Portale aktiv, Sheet weg, Sync erreichbar.
3. Später → kein Auto-Sheet mehr; Reopen-CTA im Empty-State.
4. Bestandskunden nach #138-Migration → kein Sheet.
5. Populated-XCUI unverändert nutzbar; Empty zeigt Setup-Sheet.
