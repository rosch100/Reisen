# Design: DE-Bezeichner HIG / Klartext

**Datum:** 2026-09-05
**Status:** approved (Scope A: nur sichtbare Copy; Sync-Hybrid 3)
**Scope:** Sichtbare DE/EN-Werte in `Sources/ReisenDomain/Resources/Localizable.xcstrings` plus Code-Spiegel sichtbarer Literale (`UITestingIdentifiers.copyConfirmationMenuTitleDE`, Kommentare). Keine `L10nKey`-Renames.

## Problem

Nutzer-Labels nutzen Slash-Komposita (`Reisebeginn/-ende`), deutsche Wortstummel (`Pers.`, `Buchungsnr.`, `ggf.`, `inkl.`) und inkonsistentes „Sync“ in Fließtext — nicht HIG-klar und oft kein korrektes Deutsch.

## Ziele

1. Kein `/-` in Nutzer-Labels; Suspensionsstrich („Beginn und -ende“) bleibt erlaubt.
2. Deutsche Wortstummel in Scope ausschreiben.
3. Sync-Hybrid: kurze Menü-/Tab-/Toolbar-/Dialogtitel und Alert-Buttons dürfen „Sync“ behalten; Fließtext/Status/Help/Confirm ausschreiben.
4. Tests und Menütitel-Spiegel grün halten.

## Nicht-Ziele

- Key-Renames; Accessibility-/UITest-IDs (außer sichtbarem Menütitel-Literal)
- Hardcodierte Strings außerhalb des Catalogs (z. B. `PersistenceStoreError`)
- i18n jenseits de/en; Docs unter `docs/dev/` / alte Manual-QA
- Menü-HIG-Struktur (nur Wortlaut `action.copy_confirmation`)

## Regeln (SSOT)

| Regel | Inhalt |
| --- | --- |
| Slash | Verboten in Labels; „und“ / volle Wörter |
| Wortstummel | Kein `Pers.`, `Buchungsnr.`, `ggf.`, `inkl.` in Scope |
| Sync kurz | Tab/Menü/Toolbar/Dialogtitel/Alert-Buttons: Sync / Portal-Sync / iCloud-Sync ok |
| Sync lang | Fließtext, Footer, Status, Confirm, Help, Apply-Status: Synchronisation / synchronization |
| Erlaubt | IATA, URL, z. B., Marken/Systemnamen; OAuth/2FA/MDM in technischen Footern |

## SSOT-Supersession

| Ältere Spec | Überschrieben |
| --- | --- |
| [2026-09-04-de-copy-clarity-design](2026-09-04-de-copy-clarity-design.md) | `baggage.short_personal` DE: Pers. → Persönlich |
| [2026-09-02-menu-action-labels-hig-design](2026-09-02-menu-action-labels-hig-design.md) | `action.copy_confirmation` DE: Buchungsnr. kopieren → Buchungsnummer kopieren |

## Änderungstabelle A — Slash

| Key | DE | EN |
| --- | --- | --- |
| `settings.trip_times_toggle` | Reisebeginn und -ende eintragen | Add trip start and end |
| `settings.flight_times_toggle` | Abflug und Ankunft eintragen | Add departure and arrival |

## Änderungstabelle B — Wortstummel

| Key | DE | EN |
| --- | --- | --- |
| `baggage.short_personal` | Persönlich | Personal |
| `booking.detail.confirmation_number` | Buchungsnummer | Booking number |
| `action.copy_confirmation` | Buchungsnummer kopieren | Copy Confirmation Number |
| `paste_import.source_truncated` | Quelltext gekürzt — fehlende Abschnitte gegebenenfalls manuell prüfen. | (unverändert) |
| `settings.feedback_footer_embedded` | … (einschließlich Abstürze) … | (EN already including) |
| `store.clear_icloud_message` | … (einschließlich Export der Löschungen). | (EN already including) |

Code-Spiegel: `UITestingIdentifiers.copyConfirmationMenuTitleDE` = `Buchungsnummer kopieren`; Kommentare in `BookingCopyConfirmationMenuItems`, `FieldCopyKind`.

## Änderungstabelle C — Sync-Hybrid (ausschreiben)

| Key | DE | EN |
| --- | --- | --- |
| `booking.delete_confirm_message_synced` | … Nach der nächsten Portal-Synchronisation … | … next portal synchronization … |
| `editor.sync_overwrite_warning` | Änderungen können bei der nächsten Synchronisation überschrieben werden. | Changes may be overwritten on the next synchronization. |
| `menu.sync_all_unavailable_help` | Kein Portal bereit oder Synchronisation läuft | No portal ready or synchronization in progress |
| `settings.icloud.footer.default` | … Synchronisationsdaten … | … synchronization data … |
| `settings.icloud.status.available` | … Synchronisation aktiv. | … synchronization active. |
| `settings.icloud.status.no_account` | … Synchronisationsdaten … | … Synchronization data … |
| `settings.icloud.status.restricted` | … Synchronisation ist nicht verfügbar. | … Synchronization is unavailable. |
| `settings.icloud.status.user_disabled` | iCloud-Synchronisation ist in den Einstellungen ausgeschaltet. … | iCloud synchronization is turned off in Settings. … |
| `settings.icloud_sync_label` | Daten synchronisieren über iCloud | Synchronize data via iCloud |
| `settings.reset_local_message` | … aktiver iCloud-Synchronisation … | … iCloud synchronization active … |
| `store.reset_local_message` | … aktiver iCloud-Synchronisation … | … iCloud synchronization active … |
| `sync.all.finished` | Synchronisation beendet. | Synchronization finished. |
| `sync.all.finished_with_parts` | Synchronisation beendet: %1$@. | Synchronization finished: %1$@. |
| `sync.composition_store_missing` | Synchronisationsspeicher fehlt. Bitte App neu starten. | Synchronization store is missing. Please restart the app. |
| `sync.error` | Synchronisationsfehler | Synchronization error |
| `sync.unavailable_help` | Synchronisation nicht möglich — Anmeldung und aktives Portal prüfen | Synchronization unavailable — check sign-in and active portal |
| `sync.unknown_error` | Unbekannter Synchronisationsfehler. | Unknown synchronization error. |
| `trip.delete_confirm_message_with_bookings` | … bei der nächsten Synchronisation wieder erscheinen. | … after the next synchronization. |
| `settings.icloud.disable_message` | Die Synchronisation stoppt auf diesem Gerät. … | Synchronization stops on this device. … |
| `settings.icloud.apply_status.disabling` | iCloud-Synchronisation wird gestoppt… | Turning off iCloud synchronization… |
| `settings.icloud.apply_status.disabling_wipe` | iCloud-Synchronisation wird gestoppt und geleert… | Turning off iCloud synchronization and wiping cloud data… |
| `settings.icloud.apply_status.enabling` | iCloud-Synchronisation wird eingeschaltet… | Turning on iCloud synchronization… |

## Änderungstabelle D — Unverändert (kurze Titel)

`tab.sync`, `sync.title`, `menu.provider_sync`, `action.open_sync`, `action.open_provider_sync`, `action.open_sync_short`, `action.sync_open`, `sync.provider_sync_title`, `booking.detail.sync_status_section`, `settings.icloud.disable_title`, `settings.icloud.enable_title`, `settings.icloud.disable_keep_local`, `settings.icloud.disable_wipe`, bereits ausgeschriebene Progress-Verben (`Synchronisiere…`).

## DoD

- Kein `/-` in DE/EN Nutzer-Labels des Catalogs (Scope)
- Keine `Pers.` / `Buchungsnr.` / `ggf.` / `inkl.` in Scope-Strings
- Sync-Hybrid eingehalten; Spec + Plan im Repo mit Tabellen A–D
- `L10nTests` treffen Slash, Wortstummel und Sync-Hybrid-Stichproben
- `bash ./Scripts/ci-test.sh` grün; `bash ./Scripts/macos-ui-test-remote.sh` wegen Menütitel
