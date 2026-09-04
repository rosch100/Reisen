# Bundle-ID-Umstellung: `de.reisen.Reisen` → `de.roschmac.Reisen`

Datum: 2026-09-04  
Status: umgesetzt im Repo (Developer-Portal-/ASC-App-IDs manuell nachziehen)

## Ziel

Reverse-DNS mit Developer-Kürzel statt Produkt-als-Organisation (`de.reisen…`).

## Entscheidung

| Option | Bewertung |
|--------|-----------|
| `de.rosch.reisen` | verworfen — Nutzerpräferenz zugunsten von `roschmac` |
| `de.rosch100.reisen` | möglich, länger |
| `de.roschmac.Reisen` | **gewählt** — Nutzerpräferenz; macOS- und Store-iOS-App-IDs existieren bereits im Developer Portal |

Produktsegment mit Großbuchstaben `Reisen` wie die bestehenden Portal-Einträge `de.roschmac.Reisen` / `de.roschmac.Reisen.ios` (Wiederverwendung).

## Mapping (SSOT)

| Rolle | Alt | Neu |
|-------|-----|-----|
| macOS | `de.reisen.Reisen` | `de.roschmac.Reisen` |
| iOS Store | `de.reisen.Reisen.ios` | `de.roschmac.Reisen.ios` |
| iOS Private | `de.reisen.Reisen.ios.private` | `de.roschmac.Reisen.ios.private` |
| Share / Tests | analog | analog unter `de.roschmac.Reisen…` |
| CloudKit | `iCloud.de.reisen.Reisen` | `iCloud.de.roschmac.Reisen` |
| App Groups | `group.de.reisen.Reisen…` | `group.de.roschmac.Reisen…` |
| OSLog / Keychain / UITesting-Suite | `de.reisen.Reisen…` | `de.roschmac.Reisen…` |

URL-Schemes `reisen` / `reisen-private` bleiben (Produkt-Deep-Links, kein Reverse-DNS).

## Breaking Changes

- **CloudKit:** neuer Container → keine automatische Übernahme alter iCloud-Daten unter `iCloud.de.reisen.Reisen`.
- **Keychain:** Provider-Credentials unter neuem Service-Namen → erneutes Speichern nötig.
- **App Store Connect:** Store-Eintrag `de.reisen.Reisen.ios` („Reisen Buchungen“) wird verwaist; neuer Eintrag an `de.roschmac.Reisen.ios` binden (Portal-App-ID existiert bereits).
- **Developer Portal:** Private/Share/Tests-IDs und CloudKit-Container `iCloud.de.roschmac.Reisen` anlegen bzw. an drei Targets binden.

## Developer Portal (Stand nach Umsetzung)

Per Xcode Automatic Signing angelegt/aktualisiert:

- `de.roschmac.Reisen` (macOS) — ICLOUD
- `de.roschmac.Reisen.ios` — ICLOUD, PUSH, APP_GROUPS
- `de.roschmac.Reisen.ios.private` — ICLOUD, PUSH, APP_GROUPS
- `de.roschmac.Reisen.ios.share` / `.ios.private.share` — APP_GROUPS

**Noch manuell in App Store Connect (UI):**

1. Neue Store-App an `de.roschmac.Reisen.ios` (Name z. B. Reisen Buchungen) — alter Eintrag `de.reisen.Reisen.ios` verwaist.
2. Private-App an `de.roschmac.Reisen.ios.private` (Reisen Sync) für Internal TestFlight.
3. CloudKit-Container `iCloud.de.roschmac.Reisen` in den drei App-IDs prüfen (Xcode legt oft an; im Portal unter Identifiers → iCloud Containers verifizieren).

## Nicht im Scope

- Domain-Besitz `roschmac.de` (Apple prüft das nicht).
- Migration alter CloudKit-/Keychain-Daten.
