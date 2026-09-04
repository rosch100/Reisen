# Bundle-ID-Umstellung: `de.reisen.Reisen` → `app.voyenna.reisen`

Datum: 2026-09-04  
Status: umgesetzt im Repo (Developer-Portal-/ASC-App-IDs manuell nachziehen)

## Ziel

Reverse-DNS mit Developer-Kürzel statt Produkt-als-Organisation (`de.reisen…`).

## Entscheidung

| Option | Bewertung |
|--------|-----------|
| `de.rosch.reisen` | verworfen — Nutzerpräferenz zugunsten von `roschmac` |
| `de.rosch100.reisen` | möglich, länger |
| `app.voyenna.reisen` | **gewählt** — Nutzerpräferenz; macOS- und Store-iOS-App-IDs existieren bereits im Developer Portal |

Produktsegment mit Großbuchstaben `Reisen` wie die bestehenden Portal-Einträge `app.voyenna.reisen` / `app.voyenna.reisen.ios` (Wiederverwendung).

## Mapping (SSOT)

| Rolle | Alt | Neu |
|-------|-----|-----|
| macOS | `de.reisen.Reisen` | `app.voyenna.reisen` |
| iOS Store | `de.reisen.Reisen.ios` | `app.voyenna.reisen.ios` |
| iOS Private | `de.reisen.Reisen.ios.private` | `app.voyenna.reisen.ios.private` |
| Share / Tests | analog | analog unter `app.voyenna.reisen…` |
| CloudKit | `iCloud.de.reisen.Reisen` | `iCloud.app.voyenna.reisen` |
| App Groups | `group.de.reisen.Reisen…` | `group.app.voyenna.reisen…` |
| OSLog / Keychain / UITesting-Suite | `de.reisen.Reisen…` | `app.voyenna.reisen…` |

URL-Schemes `reisen` / `reisen-private` bleiben (Produkt-Deep-Links, kein Reverse-DNS).

## Breaking Changes

- **CloudKit:** neuer Container → keine automatische Übernahme alter iCloud-Daten unter `iCloud.de.reisen.Reisen`.
- **Keychain:** Provider-Credentials unter neuem Service-Namen → erneutes Speichern nötig.
- **App Store Connect:** Store-Eintrag `de.reisen.Reisen.ios` („Reisen Buchungen“) wird verwaist; neuer Eintrag an `app.voyenna.reisen.ios` binden (Portal-App-ID existiert bereits).
- **Developer Portal:** Private/Share/Tests-IDs und CloudKit-Container `iCloud.app.voyenna.reisen` anlegen bzw. an drei Targets binden.

## Developer Portal (Stand nach Umsetzung)

Per Xcode Automatic Signing angelegt/aktualisiert:

- `app.voyenna.reisen` (macOS) — ICLOUD
- `app.voyenna.reisen.ios` — ICLOUD, PUSH, APP_GROUPS
- `app.voyenna.reisen.ios.private` — ICLOUD, PUSH, APP_GROUPS
- `app.voyenna.reisen.ios.share` / `.ios.private.share` — APP_GROUPS

**Noch manuell in App Store Connect (UI):**

1. Neue Store-App an `app.voyenna.reisen.ios` (Name z. B. Reisen Buchungen) — alter Eintrag `de.reisen.Reisen.ios` verwaist.
2. Private-App an `app.voyenna.reisen.ios.private` (Reisen Sync) für Internal TestFlight.
3. CloudKit-Container `iCloud.app.voyenna.reisen` in den drei App-IDs prüfen (Xcode legt oft an; im Portal unter Identifiers → iCloud Containers verifizieren).

## Nicht im Scope

- Domain-Besitz `roschmac.de` (Apple prüft das nicht).
- Migration alter CloudKit-/Keychain-Daten.
