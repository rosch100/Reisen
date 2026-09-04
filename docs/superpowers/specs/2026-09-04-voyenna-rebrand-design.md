# Voyenna-Rebrand (Display + Bundle-IDs)

Stand: 2026-09-04

## Zweck

App-Store-Name „Reisen“ ist belegt. Produktmarke und Bundle-IDs wechseln auf **Voyenna** / `app.voyenna.reisen…`. Swift-Module und GitHub-Repo `Reisen` bleiben unverändert (Code-/CI-Stabilität).

## Entscheidungen

| Schicht | Alt | Neu |
| --- | --- | --- |
| Display (Home Screen) | Reisen / Reisen Sync | Voyenna / Voyenna Sync |
| macOS `PRODUCT_NAME` / `.app` | Reisen | Voyenna |
| SPM executable product / Binary | `Reisen` | `Voyenna` (Target-Name bleibt `Reisen`) |
| macOS Bundle | `app.voyenna.reisen` | `app.voyenna.reisen` |
| iOS Store | `app.voyenna.reisen.ios` | `app.voyenna.reisen.ios` |
| iOS Private | `…ios.private` | `app.voyenna.reisen.ios.private` |
| Share / Tests | analog unter `app.voyenna.reisen…` | analog unter `app.voyenna.reisen…` |
| CloudKit | `iCloud.app.voyenna.reisen` | `iCloud.app.voyenna.reisen` |
| App Groups | `group.app.voyenna.reisen…` | `group.app.voyenna.reisen…` |
| URL-Schemes | `reisen` / `reisen-private` | `voyenna` / `voyenna-private` |
| Application Support | `…/Reisen` | `…/Voyenna` |
| L10n Tab/Sektion „Reisen“ (Trip-Liste) | bleibt „Reisen“ | fachlich = Trips, nicht Marke |
| macOS-Titelleiste (NavigationTitle Sidebar) | war `trip.trips` → „Reisen“ | `VoyennaBrand.displayName` |

## Nicht im Scope

- Umbenennung von SPM-Targets (`ReisenDomain`, `ReisenMac`, …)
- GitHub-Repo-/Issues-URLs (`rosch100/Reisen`)
- Domain-Kauf `voyenna.app` (manuell; Bundle setzt Ownership voraus)

## Konsequenzen

- Neue App-IDs / CloudKit-Container / App Groups im Apple Developer Portal und ASC-Einträge nötig.
- Bestehende Installationen unter `app.voyenna.reisen…` sind **kein** Update-Pfad (frische App-IDs).
- Lokale Application-Support-Daten unter `…/Reisen` werden nicht migriert (v0.2.x, bewusst).

## Akzeptanz

- `project.yml` und Entitlements spiegeln die neue ID-Hierarchie.
- Info.plist Display-Namen und Usage/Copyright nennen Voyenna.
- `PasteImportHandoffIdentity` + Plist-Tests grün.
- `reisen_macos_bundle_id` / `reisen_icloud_container_id` lesen die neuen Werte aus `project.yml`.
