# Design: iCloud-Sync in der App abwählbar

**Datum:** 2026-09-04
**Status:** approved (Ansatz 1 — Preference-Gate + Bootstrap-Reopen)
**Scope:** Domain-Key + CloudKit-Gate; AppBootstrap Live-Reopen; SharedUI-Toggle + Confirms; Logging; Tests (Unit + macOS XCUI); Doku Privacy/Hybrid-Store. macOS + iOS Hosts.

## Problem

Marketing und Privacy behaupten „iCloud optional — nur wenn du es willst“. In der App gibt es **keinen Toggle**: CloudKit ist an, sobald Env/Entitlements und ein iCloud-Account es erlauben. Nutzer können Sync nur über System-Abmeldung oder destruktives Wipe steuern — das ist keine echte Abwahl.

## Ziele

1. In den Einstellungen ist iCloud-Sync **abwählbar** (Toggle).
2. **Default an** (Opt-out): fehlender Key = Sync erlaubt — bestehende Installationen behalten heutiges Verhalten.
3. Beim Ausschalten: **C** — Sync stoppen; optional zusätzlich iCloud leeren (Confirm).
4. Änderung wirkt **live** (Container neu öffnen), kein App-Neustart nötig.
5. Preference nur lokal (UserDefaults), nicht in CloudKit.
6. Logging + Tests im selben Diff; UI-Identifier + macOS-XCUI.

## Nicht-Ziele

- Preference in CloudKit spiegeln.
- Zwei parallele ModelContainer (Cloud + Local) gleichzeitig offen halten.
- Toggle ohne Store-Wechsel (reine UI-Lüge).
- Änderung von Env-Hard-Off (`REISEN_CLOUDKIT=0`, CI, fehlende Entitlements).
- iOS-XCUI-Target (existiert nicht) — iOS Host trotzdem verdrahten; Evidence macOS XCUI + Unit/`ci-test.sh`.

## Entschiedene Alternativen

| Entscheidung | Gewählt | Verworfen |
| --- | --- | --- |
| Default | **A Opt-out (an)** | B Opt-in (aus) — bricht Sync für Bestand |
| Ausschalten | **C Sync stoppen, Wipe optional** | A nur stoppen / B immer wipe |
| Wirksamwerden | **B Live-Reopen** | A Neustart-Pflicht |
| Architektur | **1 Preference-Gate + Bootstrap-Reopen** | 2 Dual-Container / 3 UI-only-Flag |

## Begriffe (SSOT)

| Begriff | Bedeutung |
| --- | --- |
| **iCloud-Sync-Preference** | Lokales UserDefaults-Flag: Nutzer erlaubt CloudKit-Mirroring |
| **Env-Gate** | Bestehende `PersistenceBootstrap.isCloudKitEnabled…` (CI, Entitlements, `REISEN_CLOUDKIT`) |
| **Effective CloudKit** | Env-Gate **und** Preference an |
| **Disable keep local** | Preference aus; Container ohne CloudKit neu; lokale Daten bleiben; CloudKit-Daten unangetastet |
| **Disable wipe** | Wie heutiger Cloud+Local-Wipe, danach Preference aus + lokal-only reopen |
| **Enable** | Preference an; Container mit CloudKit (wenn Env erlaubt); Cloud-Merge möglich |

## Domain-Vertrag

```text
AppSettingsKeys:
  reisen_icloudSyncEnabled

isICloudSyncEnabled(defaults:) -> Bool
  fehlender Key => true
  sonst defaults.bool(forKey:)

setICloudSyncEnabled(_:defaults:)
  schreibt explizit true/false (kein stilles Löschen des Keys)
```

- Defaults-Quelle: `AppSettingsDefaults.current` (wie Provider-Setup).
- Keine neuen `UserDefaults.standard`-Call-Sites für diesen Key außerhalb der SSOT-Helfer / `@AppStorage` in SharedUI.

### CloudKit-Gate

`PersistenceBootstrap.isCloudKitEnabled…` (bzw. Aufrufer von `makeContainer`) berücksichtigt Preference:

```text
effectiveCloudKit = isCloudKitEnabledByEnvironment(...) && isICloudSyncEnabled(defaults)
```

- Env hart aus → Effective aus; Toggle disabled mit Caption.
- Preference aus → `makeContainer` öffnet Hybrid-Store mit `cloudKitDatabase: .none` für den Cloud-Store-Pfad (gleiche Dateien, kein Mirroring).

## Bootstrap-Vertrag

Neue API an `AppBootstrap` (Name exemplarisch):

```text
applyICloudSyncPreference(enabled: Bool, wipeCloud: Bool)
```

Ablauf (MainActor, `isResetting`-Guard wie Reset):

1. Diagnostic `apply_started` mit reason; vorherigen Preference-Wert merken.
2. Preference **vorläufig** schreiben (`setICloudSyncEnabled`), damit `makeContainer` den Effective-Gate sieht.
3. Observer stoppen.
4. Wenn `!enabled && wipeCloud`: bestehender Wipe-Pfad (`wipeSyncedEntities` + Export-Wait), dann Store-Reset/Reopen lokal-only.
5. Wenn `!enabled && !wipeCloud`: Container schließen/reopen **ohne** CloudKit; lokale Store-Dateien behalten (kein `resetStoreFiles`, außer der Config-Wechsel erzwingt es nachweisbar).
6. Wenn `enabled`: reopen mit CloudKit wenn Env erlaubt.
7. `activateReadyState` / Observer starten; Diagnostic `apply_succeeded`.

**Fehler:** Preference auf den gemerkten Wert **revertieren**, Diagnostic `apply_failed`, UI Alert oder `.failed` mit Retry — kein dauerhafter Widerspruch zwischen Toggle und Store.

**UITesting:** In-Memory; Preference-Apply baut Ready-State neu ohne Disk/CloudKit.

## UI-Vertrag

### Settings (SharedUI)

- iCloud-Section: **Toggle** gebunden an Preference (Label bestehend `settings.icloud_sync_label`).
- Darunter: Account-Status + Container-Detail (wie heute).
- Toggle `.disabled`, wenn Env CloudKit erzwingt-aus; Footer erklärt Env/CI.
- Accessibility-ID: `settings.icloudSyncToggle` in `UITestingIdentifiers`.

### Confirms

**Aus (true → false):** ConfirmationDialog

| Aktion | Rolle | Effekt |
| --- | --- | --- |
| Nur Sync stoppen | default | `enabled: false, wipeCloud: false` |
| Sync stoppen und iCloud leeren | destructive | `enabled: false, wipeCloud: true` |
| Abbrechen | cancel | Toggle bleibt an |

**An (false → true):** leichter Confirm — Hinweis, dass iCloud-Daten von anderen Geräten zurückkommen können — OK → `enabled: true, wipeCloud: false` / Abbrechen.

### Hosts

- macOS `Reisen.swift` Settings-Callbacks: zusätzlich `applyICloudSyncPreference`.
- iOS `MoreTab` / `ReiseniOSApp`: gleiche Verdrahtung.
- Während Apply: bestehendes `isResetting` / Store-UI.

## Logging

| Feld | Wert |
| --- | --- |
| component | `ICloudSyncPreference` |
| phase | `apply` |
| event | `apply_started` / `apply_succeeded` / `apply_failed` |
| reason | `user_disable_keep_local` \| `user_disable_wipe` \| `user_enable` |
| visibility | `.publicDiagnostic` |

Keine PII; keine Klartext-Secrets.

## Tests

| Schicht | Assert |
| --- | --- |
| Domain | Fehlender Key → an; explizit aus/an |
| Data/AppCore | Preference aus → Effective CloudKit false trotz „sonst erlaubendem“ Env-Mock; Apply keep-local vs wipe |
| SharedUI Identifier | `settings.icloudSyncToggle` |
| macOS XCUI | Settings öffnen, Toggle existiert (Smoke); Agents: `macos-ui-test-remote.sh` |

Bestehende Wipe-/Reset-/CloudKit-Env-Tests nicht schwächen.

## Doku

- `docs/dev/swiftdata-hybrid-cloudkit.md`: Preference-Gate + Live-Reopen ergänzen.
- Privacy (de/en): optionaler Satz — Sync in App-Einstellungen abwählbar; Wipe weiter destruktiv.
- Landing „iCloud optional“ bleibt gültig.

## Akzeptanz

1. Frisch/Upgrade ohne Key: Sync wie heute an (wenn iCloud/Env ok).
2. Toggle aus + „nur stoppen“: kein weiteres CloudKit-Mirroring; lokale Reisen bleiben; Re-Enable kann Cloud mergen.
3. Toggle aus + Wipe: Cloud-Daten geleert wie heutiger Clear-iCloud-Pfad; lokal-only danach.
4. Toggle an: Sync wieder aktiv (Env vorausgesetzt), live ohne Prozess-Kill.
5. Env `REISEN_CLOUDKIT=0`: Toggle disabled / Effective aus.
6. Diagnostic-Events bei Apply; Unit + Identifier + XCUI-Smoke grün.
