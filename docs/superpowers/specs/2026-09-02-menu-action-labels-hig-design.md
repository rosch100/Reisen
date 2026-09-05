# Design: Einheitliche Menü- und Aktionsbeschriftungen (HIG)

**Datum:** 2026-09-02
**Status:** approved (Ansatz A)
**Scope:** Alle sichtbaren Labels aus `action.*`, `menu.*`, plus `editor.create_title` / `editor.edit_title` und `common.edit` / `common.delete` / `common.remove`, soweit als Menü-/Toolbar-/Context-Aktion genutzt.

## Problem

Aktions- und Menütexte mischen Wortstämme und Längen:

- Neuanlage: „Neue Reise“ / „Neue Reise anlegen“ / „Neue Reise erstellen“ / „Buchung hinzufügen…“
- Create-Draft-Titel bereits „Neue Buchung“, Menü weiterhin „Buchung hinzufügen…“
- Ellipsis (`…`) nicht durchgängig an Dialog/Sheet gekoppelt
- EN Title Case vs. sentence case uneinheitlich zwischen `menu.*` und `action.*`

## Ziele

1. Kurze, prägnante, parallele Labels (DE + EN).
2. HIG: **New/Neu + Objekt** für Neuanlage; **Add/Hinzufügen** nur für echte Add-Semantik.
3. Ellipsis **nur**, wenn Dialog, Sheet, Open-Panel oder Confirm-Alert folgt.
4. Eine SSOT-Wortlaut-Tabelle für **alle** Keys im Scope.
5. XCUI: Identifier bevorzugen; Titel-Reach DE/EN mitziehen, wo heute Titel genutzt werden.

## Nicht-Ziele

- Help-/Dialog-Fließtexte (`*_help`, Confirm-Bodies, Sync-Statuszeilen wie `action.sync_provider`).
- Settings-Formulare (Kalender anlegen etc.), außer sie teilen Keys aus diesem Scope.
- i18n jenseits de/en.
- Rename von L10n-Key-Identifiern (nur sichtbarer String; Key-Rename = YAGNI).
- Accessibility-Identifier (nicht User-Titel).

## HIG-Grundlage

Apple erzeugt Container-Inhalte mit **New** (New Message / New Event / New Reminder). **Add** für „bestehendes in Sammlung“.

Reisen:

- Neue Reise / New Trip — Top-Level-Objekt
- Neue Buchung / New Booking — neues Buchungsobjekt
- Zuordnen / Assign — bestehende Offene zuweisen
- Einfügen / Paste — Import-Metapher

## Verbindliche Namensregeln

| Regel | DE | EN |
| --- | --- | --- |
| Neuanlage Objekt | `Neue {Objekt}` | `New {Object}` |
| Mutation | kurzes Verb (+ Objekt wenn nötig) | Title Case |
| Zuordnen | `… zuordnen` | `Assign …` |
| Paste | `… einfügen` | `Paste …` |
| Sofort-Aktion | ohne Füllwörter | ohne Füllwörter |
| Ellipsis | nur Dialog/Sheet/Panel/Confirm | gleich |
| DE | Erster Buchstabe groß | — |
| EN Menü/Action-Titel | Title Case | — |
| EN Fenstertitel / Editor-Chrome | Title Case (wie Menü, eine Regel) | — |

### Entschiedene Offene Punkte

| Thema | Entscheidung |
| --- | --- |
| Toolbar „Neue Buchung“ / „Neue Reise“ | **ohne** `…` (Menü **mit** `…`, wenn Sheet/Editor folgt) |
| `action.open_in_browser` | **Im Browser öffnen** / **Open in Browser** |
| Storno-Menü | **mit** `…` — Pfad kann In-App-Sheet öffnen (`BookingPortalCancelRequest.presentSheet`) |
| `action.create_trip_from_bookings` | **Neue Reise aus Auswahl** / **New Trip from Selection** (nur Selection-/Swipe-/Context) |
| `action.create_trip_from_all_open_bookings` | eigener Plural-String (nicht mit „Auswahl“ vermischen) |

## Vollständige Zielwortlaut-Tabelle

Legende `…`: ja = Zielstring endet auf `…`; nein = ohne.

### Neuanlage

| Key | DE | EN | `…` | Hinweis |
| --- | --- | --- | --- | --- |
| `menu.new_trip` | Neue Reise | New Trip | ja | Sheet |
| `action.new_trip` | Neue Reise | New Trip | nein | Toolbar/Empty |
| `action.new_trip_short` | Neue Reise | New Trip | nein | = `action.new_trip` |
| `action.create_trip` | Neue Reise | New Trip | nein | sichtbarer Text = `action.new_trip` |
| `menu.new_trip_from_selection` | Neue Reise aus Auswahl | New Trip from Selection | ja | |
| `action.create_trip_from_bookings` | Neue Reise aus Auswahl… | New Trip from Selection… | ja | Selection öffnet Trip-Create-Sheet |
| `action.create_trip_from_all_open_bookings` | Neue Reise aus allen %lld offenen Buchungen | New Trip from All %lld Open Bookings | ja | |
| `menu.add_booking` | Neue Buchung | New Booking | ja | Editor/Create |
| `action.add_booking` | Neue Buchung | New Booking | nein | Toolbar/Context |
| `editor.create_title` | Neue Buchung | New Booking | nein | Draft/Inspector |

### Bearbeiten / Löschen / Entfernen

| Key | DE | EN | `…` |
| --- | --- | --- | --- |
| `menu.edit_trip` | Reise bearbeiten | Edit Trip | ja |
| `editor.edit_title` | Buchung bearbeiten | Edit Booking | nein |
| `action.edit_gap` | Lücke bearbeiten | Edit Gap | ja |
| `common.edit` | Bearbeiten | Edit | nein |
| `action.delete_ellipsis` | Löschen | Delete | ja |
| `action.delete_trip` | Reise löschen | Delete Trip | ja |
| `action.delete_trip_confirm` | Reise löschen? | Delete Trip? | nein |
| `common.delete` | Löschen | Delete | nein |
| `common.remove` | Entfernen | Remove | nein |
| `action.remove_from_trip` | Von Reise entfernen | Remove from Trip | ja |

### Zuordnen / Einfügen

| Key | DE | EN | `…` |
| --- | --- | --- | --- |
| `menu.assign_bookings` | Buchungen zuordnen | Assign Bookings | ja |
| `action.assign_bookings` | Buchungen zuordnen | Assign Bookings | ja |
| `action.assign_to_trip` | In Reise zuordnen | Assign to Trip | ja |
| `action.assign` | Zuordnen | Assign | nein |
| `menu.paste_booking` | Buchung einfügen | Paste Booking | ja |
| `menu.paste_booking_from_file` | Buchung aus Datei einfügen | Paste Booking from File | ja |
| `menu.paste_booking_from_photo` | Buchung aus Foto einfügen | Paste Booking from Photo | ja |

### Öffnen / Navigation / Sync

Sync-Verben **aktualisieren/Refresh** und Enable-Matrix: [2026-09-05-app-menu-hig-enable-design](2026-09-05-app-menu-hig-enable-design.md) (ersetzt die Sync-Zeilen unten).

| Key | DE | EN | `…` |
| --- | --- | --- | --- |
| `menu.provider_sync` | Provider Sync | Provider Sync | nein |
| `action.open_provider_sync` | Provider Sync | Provider Sync | nein |
| `action.open_sync` | Provider Sync | Provider Sync | nein |
| `action.open_sync_short` | Sync öffnen | Open Sync | nein |
| `action.sync_open` | Sync öffnen | Open Sync | nein |
| `menu.sync_all_providers` | Alle synchronisieren | Sync All | nein |
| `action.sync_all` | Alle synchronisieren | Sync All | nein |
| `menu.sync_current_provider` | Aktuellen Provider synchronisieren | Sync Current Provider | nein |
| `action.sync_now` | Jetzt synchronisieren | Sync Now | nein |
| `action.open_booking` | Buchung öffnen | Open Booking | nein |
| `action.open_in_browser` | Im Browser öffnen | Open in Browser | nein |
| `action.open_in_provider_app` | In %1$@-App öffnen | Open in %1$@ App | nein |
| `action.open_short` | Öffnen | Open | nein |
| `action.open_keychain` | Schlüsselbundverwaltung | Keychain Access | nein |
| `action.open_passwords` | Passwords öffnen | Open Passwords | nein |
| `action.go_to_settings` | Zu den Einstellungen | Go to Settings | nein |
| `action.reload` | Erneut laden | Reload | nein |

### Portal / Credentials / Stores / Misc

| Key | DE | EN | `…` |
| --- | --- | --- | --- |
| `action.cancel_in_portal_menu` | Stornieren im Portal | Cancel in Portal | ja |
| `action.cancel_in_portal` | Stornieren | Cancel | nein |
| `action.copy_cancellation_link` | Storno-Link kopieren | Copy Cancellation Link | nein |
| `action.copy_confirmation` | Buchungsnummer kopieren | Copy Confirmation Number | nein |
| `action.copy_link` | Link kopieren | Copy Link | nein |
| `action.check_provider_sessions` | Provider-Sitzungen prüfen | Check Provider Sessions | ja |
| `action.remember_login` | Anmeldung merken | Remember Login | ja |
| `action.fill_credentials` | Ausfüllen | Autofill | nein |
| `action.save_credential` | Speichern | Save | nein |
| `action.clear_icloud` | Auch iCloud-Daten leeren | Also Wipe iCloud Data | ja |
| `action.clear_icloud_and_local` | iCloud und lokal leeren | Wipe iCloud and Local | nein |
| `action.delete_local_stores` | Lokale Stores löschen | Delete Local Stores | nein |
| `action.reset_local_stores` | Lokale Stores zurücksetzen | Reset Local Stores | ja |
| `action.understood` | Verstanden | Got It | nein |

### Out-of-Scope (keine Label-Änderung in diesem Feature)

| Key | Grund |
| --- | --- |
| `action.cancel_in_portal_help` | Fließtext |
| `action.open_in_browser_help` | Fließtext |
| `action.sync_all_help` | Fließtext |
| `action.sync_provider` | Statuszeile, kein Menübefehl |
| `trip.*_help` und ähnliche Help-Keys | Fließtext |

### Editor-Feld-Add (unverändert, Add-Semantik)

`editor.add_passenger`, `editor.add_hint`, `editor.add_baggage`, `editor.add_cancellation_deadline` — weiterhin „… hinzufügen“ / „Add …“.

## Ellipsis-Audit (DoD)

Vor Ship jede Call-Site der Tabelle gegen UI-Pfad prüfen. Abweichungen nur mit Begründung in der Implementierungs-PR.

## Implementierungsrichtung

1. `Localizable.xcstrings` DE/EN exakt nach Tabelle.
2. Doppelte Create-Trip-Toolbar-Keys auf identischen sichtbaren String.
3. Call-Sites nur bei falschem Key; kein Key-Rename.
4. Tests: XCUI/String-Reach anpassen; Identifier-Tests unverändert.
5. Diese Spec ist Label-SSOT.

## Risiken

- Gewöhnung an „Buchung hinzufügen…“ — bewusst HIG-parallel.
- XCUI Titel-Reach — Identifier bevorzugen.
- `check_provider_sessions`: Ellipsis bei Impl. gegen Call-Site bestätigen.

## Akzeptanzkriterien

1. Kein sichtbares „anlegen“ / „erstellen“ / „hinzufügen“ für **Neue Reise** / **Neue Buchung** (Ausnahme Editor-Feld-Add; Paste = „einfügen“).
2. Parallelität Neue Reise ↔ Neue Buchung; Edit Trip ↔ Edit Booking / Edit Gap.
3. Alle Keys der vollständigen Tabelle umgesetzt; Ellipsis-Spalte eingehalten.
4. Unit-/XCUI grün; Asserts nicht geschwächt.
5. EN Title Case für alle Menü-/Action-Titel der Tabelle.
