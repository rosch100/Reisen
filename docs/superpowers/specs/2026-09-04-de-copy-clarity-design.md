# Design: DE-Copy-Klarheit (Terminologie + Semantik)

**Datum:** 2026-09-04
**Status:** approved (Ansatz A — Katalog + Editor-Offset-Entfernung, keine Key-Renames)
**Scope:** Sichtbare DE- (und parallel betroffene EN-) Strings in `Sources/ReisenDomain/Resources/Localizable.xcstrings`, plus Entfernen der Offset-Eingabefelder im Buchungseditor (`BookingEditor`). Keine Key-Identifier-Renames. Menü-Aktionslabels aus [menu-action-labels-hig](2026-09-02-menu-action-labels-hig-design.md) bleiben strukturell (Neue Reise / Ellipsis); diese Spec ergänzt Klarheit und Begriffs-SSOT.

## Problem

Die UI mischt Fachbegriffe und Anglizismen so, dass Bedeutungen uneinheitlich oder unklar werden:

- **Provider / Portal / Anbieter** für dieselbe Buchungsquellen-Idee
- **Reisen** als App-Marke vs. Plural der Trips (Marke ist **Voyenna**)
- **Passwort / Kennwort / Passwords**
- **Sichern / Speichern**
- Entwicklersprache (**Stores**, `foundBookings=`, **Pax**, **Fix**, **Policy**)
- Zeitzonen-**Offsets** fälschlich als Editor-UI (interne Parameter)

## Ziele

1. Eine verbindliche Begriffs-SSOT für Nutzer-Copy (DE; EN dort, wo Semantik/Marke mitzieht).
2. Kritische Unklarheiten und Tippfehler beseitigen.
3. Technik-Jargon in Nutzerflächen entschärfen, ohne Domain-Keys umzubenennen.
4. `L10nTests` und betroffene String-Asserts grün halten.

## Nicht-Ziele

- Key-Rename in `L10nKey` / rawValues.
- Änderung der Menü-HIG-Tabelle (Neue Reise / Ellipsis-Regeln), außer ein Key in dieser Spec explizit neu gesetzt wird.
- i18n jenseits de/en.
- Umformulieren aller langen Feedback-Footers (nur klare Fehler/Marke/Terminologie).
- Code-Kommentare, Specs/Plans außerhalb L10n, Diagnostik-Logs.

## Entschiedene Regeln (SSOT)

| Thema | DE-Regel | EN-Regel |
| --- | --- | --- |
| Buchungsquelle (Booking.com, …) | **Portal** / Buchungsportal | **Portal** / booking portal (kein „Provider“ in Nutzer-Copy) |
| Betreiber-Feld (Airline, …) | **Anbieter** (unverändert wo schon so) | Provider / Operator je bestehendem Key |
| Trip-Liste / Tab / „keine Reisen“ | **Reisen** = Trips (fachlich) | Trips |
| App-Marke in Fließtext | **Voyenna** | **Voyenna** |
| Kalendername „Reisen“ / Global-Kalender | bleibt „Reisen“ als Kalender-Titel | Global (“Trips”) unverändert |
| Passwort-Feld und -Konto | **Passwort** (nicht Kennwort) | Password |
| System-App Passwords | **Passwörter** / Passwörter-App | Passwords (Systemname EN) |
| Speichern-Aktion | **Speichern** (ein Verb) | Save |
| Lokale Persistenz | **Lokale Daten** / Datendateien (nicht „Stores“) | Local data / local data files |
| Erinnerungslisten | **Erinnerungsliste** (nicht Reminder-Liste) | Reminder list (EN Apple-nah ok) |
| Storno-Kurzlabel Sektion | **Stornierung** | Cancellation |
| Zeitleiste-UI | **Zeitachse** | Timeline (EN üblich) |
| Gepäck Kurz „Personal“ | **Persönlich** (ersetzt Pers.; siehe [de-label-hig-clarity](2026-09-05-de-label-hig-clarity-design.md)) | Personal |
| Passagierzeile | **Passagier %d** | Passenger %d (statt Pax) |

## Vollständige Änderungstabelle

Nur Keys mit **sichtbarer** Änderung. Wert = neuer DE-String; EN nur wenn Spalte „EN“ gefüllt.

### A — Kritisch / Korrektur

| Key | DE neu | EN neu (falls) |
| --- | --- | --- |
| `baggage.short_personal` | Persönlich | — |
| `baggage.passenger_line` | Passagier %1$d: %2$@ | Passenger %1$d: %2$@ |
| `booking.cancellation.locked` | Nicht mehr kostenlos stornierbar | No longer free to cancel |
| `sync_result.no_deadlines` | Keine Stornofristen gefunden (%1$d Buchungen). | No cancellation deadlines found (%1$d bookings). |
| `action.assign_to_trip` | Einer Reise zuordnen… | — |
| `booking.field.location_from_address.ferry` | Abfahrtsadresse | — |
| `github.no_comment_this_hour` | Kein neuer Kommentar in dieser Stunde. | — |

### B — Marke Voyenna (App-Bezug; Trips bleiben „Reisen“)

| Key | DE neu | EN neu |
| --- | --- | --- |
| `action.cancel_in_portal_help` | Öffnet die Stornoseite beim Portal. Storniert die Buchung nicht in Voyenna. | Opens the portal’s cancellation page. Does not cancel the booking in Voyenna. |
| `booking.delete_confirm_message` | Die Buchung wird unwiderruflich aus Voyenna entfernt. | The booking will be permanently removed from Voyenna. |
| `booking.delete_confirm_message_synced` | Die Buchung wird unwiderruflich aus Voyenna entfernt. Nach dem nächsten Portal-Sync kann sie wieder erscheinen, wenn sie beim Portal noch existiert. | The booking will be permanently removed from Voyenna. After the next portal sync it may reappear if it still exists at the portal. |
| `credential.saved_account_footer` | Passwort-Konto für %1$@ — nach dem Speichern füllt Voyenna die Felder beim nächsten Login automatisch aus. | Password account for %1$@ — after saving, Voyenna autofills the fields on the next login. |
| `privacy.denial.calendars` | … für „Voyenna“ den Schalter. | … enable Voyenna under … |
| `privacy.denial.notifications` | … Mitteilungen für „Voyenna“. | … notifications for Voyenna … |
| `privacy.denial.reminders` | … für „Voyenna“ den Schalter. | … enable Voyenna under … |
| `settings.icloud.footer.no_account` | … damit Voyenna zwischen Geräten synchronisiert. | … to sync Voyenna across devices. |
| `settings.remember_password_footer` | Speichert E-Mail und Passwort … automatisch in Voyenna. … nicht als Passwort gespeichert. | … automatically in Voyenna. … not stored as passwords. |
| `guest_hint.event_notes_header` | Voyenna: %1$@ | Voyenna: %1$@ |
| `guest_hint.reminder_notes_header` | Voyenna: %1$@ | Voyenna: %1$@ |

Nicht ändern (Trips/Kalender-Titel): `tab.trips`, `trip.trips`, `trip.no_trips*`, `trip.search_trips`, `trip.selected_trips`, `settings.calendar_title_global`, `settings.clear_icloud_message` („Synchronisierte Reisen…“ = Trips), `settings.icloud_footer` / `settings.icloud_container_detail` (Satzanfang „Reisen, Buchungen…“ = Trips).

### C — Portal statt Provider (Nutzer-Copy)

| Key | DE neu | EN neu |
| --- | --- | --- |
| `action.check_provider_sessions` | Portal-Sitzungen prüfen… | Check Portal Sessions… |
| `action.open_provider_sync` | Portal-Sync | Portal Sync |
| `action.open_sync` | Portal-Sync | Portal Sync |
| `action.sync_all_help` | Alle aktivierten, angemeldeten Portale nacheinander synchronisieren | Sync all enabled, signed-in portals one after another |
| `menu.provider_sync` | Portal-Sync | Portal Sync |
| `menu.sync_current_provider` | Aktuelles Portal synchronisieren | Sync Current Portal |
| `editor.provider` | Portal | Portal |
| `login_status.gray` | Portal deaktiviert | Portal disabled |
| `provider.activate_help` | Portal aktivieren | Enable portal |
| `provider.deactivate_help` | Portal deaktivieren | Disable portal |
| `settings.legal.footer` | Beschreibt Portal-Logins, iCloud, Kalender, Diagnosen und lokale Speicherung. | Describes portal logins, iCloud, calendar, diagnostics, and local storage. |
| `settings.provider_login` | Portal-Anmeldung | Portal sign-in |
| `sync.all.all_providers_synced` | Alle Portale synchronisiert (%1$d). | All portals synced (%1$d). |
| `sync.no_logged_in_providers` | Keine angemeldeten Portale zum Synchronisieren. | No signed-in portals to sync. |
| `sync.provider` | Portal | Portal |
| `sync.provider_disabled` | Portal %1$@ ist deaktiviert. | Portal %1$@ is disabled. |
| `sync.provider_disabled_hint` | Aktiviere das Portal über die Checkbox in der Seitenleiste. | Enable the portal via the checkbox in the sidebar. |
| `sync.provider_picker_hint` | Wähle das Buchungsportal für die Anmeldung und Synchronisation. | — (bereits portal) |
| `sync.provider_sessions_checking` | Portal-Sitzungen prüfen… | Checking portal sessions… |
| `sync.provider_sync_title` | Portal-Sync | Portal Sync |
| `sync.provider_unavailable` | Portal %1$@ ist nicht verfügbar. | Portal %1$@ is not available. |
| `sync.unavailable_help` | Sync nicht möglich — Anmeldung und aktives Portal prüfen | Sync unavailable — check sign-in and active portal |
| `trip.no_open_bookings_hint` | … Synchronisiere ein Portal oder lege eine Reise an. | … Sync a portal or create a trip. |
| `trip.no_trips_hint` | … synchronisiere Buchungen von einem Portal. | … sync bookings from a portal. |
| `trip.select_sidebar_or_provider` | Wähle eine Reise oder ein Portal in der Seitenleiste. | Select a trip or a portal in the sidebar. |
| `trip.select_trip_or_sync` | … oder synchronisiere zuerst ein Portal. | … or sync a portal first. |
| `credential.session_persistence_footer` | … solange das Portal die Session akzeptiert. … | … while the portal accepts the session. … |

Entwickler-/Diagnose-nahe Keys (Composition, Registry, Keychain-Host, Login-Metadaten) → ebenfalls Portal-Wortlaut, ohne Debug-Kauderwelsch wo vermeidbar:

| Key | DE neu | EN neu |
| --- | --- | --- |
| `sync.composition_registry_missing` | Interne Portal-Registry fehlt. Bitte App neu starten. | Internal portal registry is missing. Please restart the app. |
| `sync.composition_store_missing` | Sync-Speicher fehlt. Bitte App neu starten. | Sync store is missing. Please restart the app. |
| `sync.no_keychain_host` | Für dieses Portal ist kein Schlüsselbund-Host konfiguriert. | No keychain host configured for this portal. |
| `sync.provider_login_metadata_missing` | Login-Daten fehlen für Portal %1$@. | Login metadata is missing for portal %1$@. |

`provider.activate` / `deactivate` / `activate_named` bleiben Verb-Labels ohne „Provider“-Substantiv (bereits ok).

### D — Passwort / Passwörter / Speichern

| Key | DE neu | EN |
| --- | --- | --- |
| `common.save` | Speichern | — |
| `credential.password` | Passwort | — |
| `credential.copy_from_passwords_footer` | … Kennwort → Passwort; Passwords-App → Passwörter-App | — |
| `action.open_passwords` | Passwörter öffnen | — |
| `sync.passwords_app_not_found` | Passwörter-App wurde nicht gefunden. | — |
| `sync.keychain_accounts_found` | … Fehlt ein Passwörter-Konto: … | — |
| `settings.remember_password_toggle` | Passwort nach Login speichern | — |
| `sync.fill_credentials_help` | E-Mail und Passwort … | — |
| `sync.remember_login_help` | Passwort-Konto speichern oder Session-Hinweis … | — |
| `credential.oauth_session_footer` | … nicht als Passwort. | — |
| `sync.sync_bookings_help` | Buchungen dieses Portals jetzt synchronisieren | Sync this portal's bookings now |
| `sync.sync_now_help` | Aktivitäten und Stornofristen dieses Portals lokal aktualisieren | Update this portal's activities and cancellation deadlines locally |

### E — Stores → Daten; Reminder → Erinnerung; Technik entschärfen

| Key | DE neu | EN neu |
| --- | --- | --- |
| `action.delete_local_stores` | Lokale Daten löschen | Delete Local Data |
| `action.reset_local_stores` | Lokale Daten zurücksetzen… | Reset Local Data… |
| `settings.reset_local_confirm_title` | Lokale Daten zurücksetzen? | Reset local data? |
| `settings.data_footer` | … entfernt nur Datendateien auf diesem Gerät. … | … removes data files on this device only. … |
| `store.clear_icloud_message` | Lokale Daten werden neu angelegt, … | Local data is recreated, … |
| `store.reset_local_message` | Lokale Datendateien werden gelöscht. … | Local data files will be deleted. … |
| `app.settings_unavailable` | Einstellungen sind erst nach erfolgreichem Start der Datenbank verfügbar. | Settings are available only after the database starts successfully. |
| `settings.create_new_reminder_list` | Neue Erinnerungsliste anlegen… | — |
| `settings.create_reminder_list_auto` | Erinnerungsliste automatisch anlegen | — |
| `settings.new_reminder_list` | Neue Erinnerungsliste | — |
| `settings.reminder_list_picker` | Erinnerungsliste | — |
| `editor.policy_text` | Stornobedingungen | Cancellation policy |
| `paste_import.model_on_device` | Auf dem Gerät | On Device |
| `trip.timeline` | Zeitachse | — |
| `gap.kind_transport` | Zwischentransport | — |
| `settings.calendar_title_global` | Gemeinsam („Reisen“) | Global (“Trips”) |
| `settings.lead_times_days` | Vorlaufzeiten in Tagen | — |
| `settings.currency.footer` | … (über den Frankfurter-Kursdienst). … | … (via the Frankfurter rate service). … |
| `deep_link.missing_destination` | Zielhinweis fehlt (Ziel/Ort konnte nicht aus Buchungen abgeleitet werden). | — |
| `trip.storno` | Stornierung | — |
| `trip.no_cancellation_info` | Keine Stornierungsinfos | No cancellation info (EN unverändert ok) |
| `action.fill_credentials` | Zugangsdaten ausfüllen | Autofill credentials |
| `assign.title` | Buchungen zuordnen | Assign bookings (Ellipsis aus Titel entfernen) |

### Nicht-UI: Zeitzonen-Offsets

`hotelOffsetSeconds` / Flug-Offsets / Deadline-Offsets sind **interne Berechnungsparameter** (Ortszeit). Sie dürfen **nicht** als Editor- oder Detailfelder angezeigt werden. Zugehörige Keys (`editor.arrival_offset`, `editor.departure_offset`, `editor.hotel_offset`, `editor.offset_seconds`, `editor.field.*_offset`) sind keine Nutzer-Copy; Editor speichert vorhandene Werte still mit, ohne Eingabefelder.

### F — Leicht / Feinschliff (mitziehen)

| Key | DE neu |
| --- | --- |
| `settings.travel_times_footer` | Zeitzonen werden aus vorhandenen Ortszeiten abgeleitet. |

## Out of Scope (bewusst unverändert)

- Tab `Sync`, Statuszeilen `Synchronisiere…` (etabliertes Lehnwort)
- `booking.type.activity` = Erlebnis
- Check-in / Check-out (Reise-Standardsprache)
- Lange `settings.feedback_footer_*` (Inhalt/Recht; kein Klarheits-Blocker)
- Privacy-Pfad `%1$@ → Datenschutz` (Systemnamen)

## Tests

- `L10nTests` (alle Keys de/en nicht-leer)
- `BaggageInfoFormatterTests`: Asserts von `Pax` auf `Passagier` / `L10n.format(.baggagePassengerLine, …)` umstellen
- `BookingEditorValidationTests`: interne Offset-Texte lösen keine Validierungsfehler aus; Offset-Felder nicht mehr im Editor
- XCUI bevorzugt Identifier; Titel-Reach nur anpassen, falls hardcodierte DE-Titel brechen (Smoke Identifier-first)

## Akzeptanz

1. Kein Nutzer-DE mit „Kennwort“, „Passwords öffnen“, „Lokale Stores“, „Pax“, „Fix (“, `foundBookings=`, „Abfahrtadresse“, „In Reise zuordnen“.
2. App-Marke in Fließtext = Voyenna; Trip-Plural/Tab = Reisen.
3. Nutzer-Copy für Buchungsquellen = Portal (nicht Provider), außer Betreiber-Feld Anbieter.
4. Keine sichtbaren Editor-/Detailfelder für Zeitzonen-Offsets (interne Parameter).
5. `bash ./Scripts/ci-test.sh` grün für Domain/L10n-relevante Suites.
6. XCUI für diesen Diff nicht erforderlich (keine Identifier-/Smoke-Änderung).
