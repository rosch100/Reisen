# Design: iCloud Provider-Prefs + Credential-Sync

**Datum:** 2026-09-04
**Status:** approved (Plan hybrid — feature-dev)
**Scope:** CloudKit-Mirror für Provider-Enablement + `setupCompleted`; iCloud-Keychain für App-Credentials; Import-Gate vor First-Launch-Sheet. Baut auf First-Launch-Setup und Hybrid-CloudKit auf.

## Problem

Auf einem Zweitgerät (gleiche iCloud) erscheinen Reisen/Buchungen per CloudKit, aber Provider-Toggles und Setup-Flags sind lokal — das First-Launch-Sheet fragt erneut. Gespeicherte Portal-Passwörter (App-Keychain) sind `ThisDeviceOnly` und fehlen für den JS-Fill-Pfad.

## Ziele

1. `providerEnabled_*` und `setupCompleted` geräteübergreifend via CloudKit spiegeln.
2. App-GenericPassword-Credentials via `kSecAttrSynchronizable` (iCloud-Keychain) syncen.
3. First-Launch-Sheet auf Zweitgerät skippen, wenn synced `setupCompleted`.
4. Privacy DE/EN an reales Verhalten anpassen (Pflicht).
5. Cookies/Sessions bleiben gerätegebunden.

## Nicht-Ziele

- Cookie-/WKWebView-Session-Sync.
- Preferred Keychain-Account-IDs in CloudKit (Username-PII).
- `setupDeferred` syncen (gerätelokal).
- System-Passwords-Popover / Browser-Entitlement.
- Passwörter in CloudKit-Records.
- NSUbiquitousKeyValueStore (Compliance ohne KVS-Entitlement).

## Entschiedener Ansatz

| Daten | Sync | Mechanismus |
| --- | --- | --- |
| `providerEnabled_*` | ja | `SDProviderPreferences` im `reisen-cloud`-Store |
| `setupCompleted` | ja | gleiches Singleton |
| `setupDeferred` | nein | lokal |
| Preferred Keychain-Account | nein | lokal / Single-Account-Auto auf B |
| Username/Password | ja | GenericPassword + `kSecAttrSynchronizable` |
| Cookies | nein | — |

### Keychain-Konformität

Passwords-App-Internetpasswörter und Reisen-GenericPasswords sind getrennte Stores. Passwords-Sync hilft Reisen nicht (nicht lesbar; kein Autofill in Sync-WKWebView). App-`synchronizable` nutzt denselben iCloud-Keychain-Schalter und liefert zusätzlichen Nutzen für JS-Fill. Ohne iCloud-Keychain: Items lokal; Prefs weiter über CloudKit.

## SSOT

- **Runtime:** `AppSettingsDefaults` / `AppSettingsKeys`.
- **CloudKit:** Mirror (Enable-Flags + `setupCompleted`); kein zweites Settings-API.
- **Export:** nach lokaler Mutation upsert Singleton.
- **Import:** Snapshot vollständig auf Prefs-Keys anwenden (kein Partial-Merge-Dummy).
- **Konflikt:** CloudKit last-writer-wins.

## Modell

- `SDProviderPreferences` — Singleton mit fester ID `ProviderPreferencesRecordID.singleton`.
- Felder: `setupCompleted: Bool`, `enabledProviderRawCSV: String`.
- Schema: `ReisenSchemaV11` als Modell-Listen-Erweiterung; **keine** `ReisenMigrationPlan.stages`.
- Duplikate: kanonische ID behalten, übrige löschen.

## Verhalten

1. Gerät A Continue → lokal + Export Prefs; Credentials synchronizable speichern.
2. Gerät B Import → Apply → kein Sheet wenn `setupCompleted`.
3. **Import-Gate vor Present:** kurzer Wait auf initialen Import; Timeout → Sheet. UITesting/`REISEN_CLOUDKIT=0`/CI: Gate sofort complete.
4. **Post-Present:** Sheet sichtbar, später Import mit `setupCompleted` → Apply + dismiss; reason `icloud_prefs_late`. Nur Enables ohne completed → Sheet bleibt.
5. **Degraded:** CloudKit an, Keychain-Sync aus → Prefs/Skip ok; Login manuell / Konto speichern.
6. **Migration:** bestehende `ThisDeviceOnly`-Items → synchronizable unter bestehendem Opt-in; kein neuer Consent-Dialog; in Privacy benennen.

## Logging

| event | result | reason |
| --- | --- | --- |
| `prefs_import` | started / succeeded / timedOut | stable machine strings |
| `provider_setup_skipped` | skipped | `icloud_prefs` / `icloud_prefs_late` |
| `prefs_export` | succeeded / failed | — |
| keychain migrate/save | succeeded / failed | counts only — keine Usernames/Passwörter/Account-IDs |
| `keychain_sync_unavailable` | skipped | when diagnostically useful |

## Privacy (Pflicht)

`docs/legal/privacy.html` + `en/privacy.html`: device-only-Claim ersetzen; iCloud-Keychain für Opt-in-Portal-Passwörter; CloudKit-Prefs ohne Passwörter/Usernames; Cookies gerätegebunden; Migration als Verhaltensänderung der Opt-in-Speicherung.

## Tests

- Unit: export/import; Singleton; Gate; Late-Dismiss; Keychain synchronizable + Migration; UITesting Gate sofort.
- HybridTwoDevice: Prefs auf B sichtbar.
- XCUI: Empty/Populated First-Launch unverändert (Gate sofort).
- Logging ohne PII.

## open_gaps

- Echtes iCloud-Keychain E2E: manuell / Acceptance.
- Live CloudKit Prefs: Two-Device-Skript wo machbar, sonst manuell.

## Akzeptanz

1. A Continue → B ohne Sheet, gleiche Enables.
2. Credentials mit iCloud-Keychain → JS-Fill auf B möglich ohne erneutes „Konto speichern“.
3. Ohne iCloud-Keychain → Prefs syncen, Credentials lokal.
4. Privacy DE/EN stimmt mit Verhalten überein.
5. Cookies bleiben gerätegebunden.
