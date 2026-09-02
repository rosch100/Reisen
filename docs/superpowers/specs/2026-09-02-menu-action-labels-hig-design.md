# Design: Einheitliche Menü- und Aktionsbeschriftungen (HIG)

Datum: 2026-09-02  
Status: draft — Freigabe Ansatz A durch Nutzer  
Scope: alle sichtbaren Menü-/Context-/Toolbar-Aktionen (`action.*`, `menu.*`, Create-/Edit-Editor-Titel)

## Problem

Aktions- und Menütexte mischen Wortstämme und Längen:

- Neuanlage: „Neue Reise“ / „Neue Reise anlegen“ / „Neue Reise erstellen“ / „Buchung hinzufügen…“
- Create-Draft-Titel bereits „Neue Buchung“, Menü weiterhin „Buchung hinzufügen…“
- Ellipsis (`…`) nicht durchgängig an Dialog/Sheet gekoppelt
- EN Title Case vs. sentence case uneinheitlich zwischen `menu.*` und `action.*`

Das wirkt unpräzise und nicht HIG-konform.

## Ziele

1. Kurze, prägnante, parallele Labels (DE + EN).
2. HIG: **New/Neu + Objekt** für Neuanlage; **Add/Hinzufügen** nur für echte Add-Semantik (bestehendes/Anhang/Listenfeld).
3. Ellipsis **nur**, wenn Dialog, Sheet, Open-Panel oder Confirm-Alert folgt.
4. Eine SSOT-Wortlaut-Tabelle; Duplikat-Keys auf denselben String legen, wo sinnvoll.
5. XCUI-Reach über stabile Identifier wo möglich; wo Titel-Reach nötig ist, DE/EN mitziehen.

## Nicht-Ziele

- Fließtexte (Help, Dialog-Bodies, Sync-Statuszeilen).
- Settings-Formulierungen außer klaren Aktionsbuttons, die wie Menüeinträge wirken (optionaler Follow-up).
- i18n jenseits de/en.
- Umbenennung von Accessibility-Identifiern, die keine User-sichtbaren Titel sind.

## HIG-Grundlage (Best Practice)

Apple-Produktivitätsapps erzeugen Container-Inhalte mit **New**, nicht Add:

- Mail: New Message  
- Calendar: New Event  
- Reminders: New Reminder  

**Add** typisch für „bestehendes in Sammlung“ (Add to Album, Add Account).

Reisen:

- Neue Reise / New Trip — neues Top-Level-Objekt  
- Neue Buchung / New Booking — neues Buchungsobjekt (auch wenn der Trip der Container ist)  
- Buchungen zuordnen / Assign Bookings — bestehende Offene einer Reise zuweisen (= Add-Semantik ohne „Neue“)

## Namensregeln

| Regel | DE | EN |
| --- | --- | --- |
| Neuanlage Objekt | `Neue {Objekt}` | `New {Object}` (Menu Title Case) |
| Mutation | kurzes Verb (+ Objekt nur wenn nötig) | Title Case Verb (+ Object) |
| Zuordnen bestehender | `… zuordnen` | `Assign …` |
| Paste-Import | `… einfügen` | `Paste …` |
| Öffnen / Sync sofort | ohne Ausschmückung | ohne Ausschmückung |
| Ellipsis | nur Dialog/Sheet/Panel/Confirm | gleich |
| DE Orthografie | Erster Buchstabe groß, sonst klein (außer Eigennamen) | — |
| EN Menüs | Title Case | — |

Toolbar: darf denselben **kurzen** Wortlaut **ohne** `…` nutzen, wenn der Menüeintrag `…` hat (Platz/HIG-Toolbar-Praxis). Keys können getrennt bleiben (`menu.*` vs `action.*`), Inhalt parallel.

## Zielwortlaut (Kern-SSOT)

### Neuanlage

| Rolle | Key(s) | DE | EN | `…` |
| --- | --- | --- | --- | --- |
| Menü neue Reise | `menu.new_trip` | Neue Reise | New Trip | ja (Sheet) |
| Toolbar/Empty neue Reise | `action.new_trip`, `action.new_trip_short`, `action.create_trip` | Neue Reise | New Trip | nein (Toolbar) bzw. Keys auf denselben Text legen |
| Neue Reise aus Auswahl | `menu.new_trip_from_selection` | Neue Reise aus Auswahl | New Trip from Selection | ja |
| Neue Reise aus offenen (plural) | `action.create_trip_from_all_open_bookings` | Neue Reise aus allen %lld offenen Buchungen | New Trip from All %lld Open Bookings | ja |
| Aus Buchungen (Label) | `action.create_trip_from_bookings` | Neue Reise aus Auswahl | New Trip from Selection | angleichen an Selection-Variante; kein „erstellen“ |
| Menü/Context/Toolbar Buchung | `menu.add_booking`, `action.add_booking` | Neue Buchung | New Booking | Menü ja; Toolbar optional ohne |
| Editor-/Draft-Titel Create | `editor.create_title` | Neue Buchung | New Booking | nein |

Hinweis: Key-Namen `add_booking` dürfen vorerst bleiben (Wire-Stabilität); **sichtbarer** String folgt „Neue Buchung“. Rename der Keys ist optional/YAGNI.

### Bearbeiten / Löschen / Entfernen

| Rolle | Key(s) | DE | EN | `…` |
| --- | --- | --- | --- | --- |
| Reise bearbeiten | `menu.edit_trip` | Reise bearbeiten | Edit Trip | ja (Sheet) |
| Buchung bearbeiten (Titel) | `editor.edit_title` | Buchung bearbeiten | Edit Booking | nein |
| Lücke bearbeiten | `action.edit_gap` | Lücke bearbeiten | Edit Gap | ja (Sheet) |
| Common Edit (Context) | `common.edit` | Bearbeiten | Edit | nein |
| Löschen mit Confirm | `action.delete_ellipsis`, `action.delete_trip` | Löschen / Reise löschen | Delete / Delete Trip | ja |
| Common Delete ohne Dialog | `common.delete` | Löschen | Delete | nein |
| Von Reise entfernen (Confirm) | `action.remove_from_trip` | Von Reise entfernen | Remove from Trip | ja |

### Zuordnen / Einfügen / Öffnen / Sync

| Rolle | Key(s) | DE | EN | `…` |
| --- | --- | --- | --- | --- |
| Buchungen zuordnen | `menu.assign_bookings`, `action.assign_bookings` | Buchungen zuordnen | Assign Bookings | ja |
| In Reise zuordnen | `action.assign_to_trip` | In Reise zuordnen | Assign to Trip | ja |
| Zuordnen (kurz) | `action.assign` | Zuordnen | Assign | kontextabhängig |
| Buchung einfügen | `menu.paste_booking` | Buchung einfügen | Paste Booking | ja |
| Aus Datei / Foto | `menu.paste_booking_from_file`, `…_photo` | Buchung aus Datei/Foto einfügen | Paste Booking from File/Photo | ja |
| Provider Sync (Menü) | `menu.provider_sync` | Provider Sync | Provider Sync | nein (nur Navigation) |
| Alle synchronisieren | `menu.sync_all_providers`, `action.sync_all` | Alle synchronisieren | Sync All | nein |
| Aktuellen Provider sync | `menu.sync_current_provider` | Aktuellen Provider synchronisieren | Sync Current Provider | nein |
| Jetzt synchronisieren | `action.sync_now` | Jetzt synchronisieren | Sync Now | nein |
| Browser öffnen | `action.open_in_browser` | Im Browser öffnen | Open in Browser | nein |
| Stornieren im Portal | `action.cancel_in_portal_menu` | Stornieren im Portal | Cancel in Portal | nein (öffnet URL/Sheet — wenn Sheet: `…`) |

### Editor-interne „Hinzufügen“ (bleiben Add-Semantik)

Unverändert im Sinne von *Add row to form*:

- `editor.add_passenger` / `editor.add_hint` / `editor.add_baggage` / `editor.add_cancellation_deadline`

Das ist korrektes *Add*, nicht *New Object*.

## Ellipsis-Audit (verbindlich)

Vor Ship jede `action.*`/`menu.*`-Nutzung gegen UI-Pfad prüfen:

- Sheet / Editor / Open-Panel / Confirm → `…`  
- Sofortige Side-Effect (Sync, URL öffnen, Copy) → kein `…`  
- Navigation zu bestehender Spalte/Ansicht → kein `…`

Abweichungen nur mit Kommentar in der Spec-Tabelle.

## Implementierungsrichtung

1. `Localizable.xcstrings` DE/EN an Zielwortlaut anpassen.  
2. Doppelte Create-Trip-Keys (`action.create_trip`, `action.new_trip`, `action.new_trip_short`) auf identischen sichtbaren String.  
3. Call-Sites nur ändern, wenn falscher Key (z. B. Help statt Action) — kein unnötiges Key-Rename.  
4. Tests: String-Asserts / XCUI-Titel-Reach (z. B. „Buchung hinzufügen…“ → „Neue Buchung…“); Identifier-basierte Tests unberührt.  
5. Kurzer Hinweis in `docs/dev` oder bestehendem HIG-Review optional; Spec hier ist SSOT.

## Risiken

- Nutzer gewohnt an „Buchung hinzufügen…“ — kurz, parallel zu Reise, HIG-begründet.  
- XCUI flaky bei Titel-Reach — bevorzugt Identifier; Titel nur wo heute schon so.  
- Confirm vs. sofortiges Entfernen: falsches Ellipsis → Audit-Pflicht.

## Akzeptanzkriterien

1. Kein sichtbares „anlegen“ / „erstellen“ / „hinzufügen“ mehr für **Neue Reise** / **Neue Buchung** (außer Editor-Feld-Add und Paste „einfügen“).  
2. Parallelität: Neue Reise ↔ Neue Buchung; Edit Trip ↔ Edit Booking / Edit Gap.  
3. Ellipsis-Regel für alle `menu.*`/`action.*` im Scope verifiziert.  
4. Unit-/XCUI grün; keine geschwächten Asserts.  
5. EN Menu Title Case konsistent in `menu.*`.

## Offene Punkte (bewusst klein)

- Ob Toolbar-Buttons für Neue Buchung `…` weglassen (Empfehlung: ja, ohne `…`).  
- Ob `action.open_in_browser` von „Buchung im Browser öffnen“ auf „Im Browser öffnen“ gekürzt wird (Empfehlung: ja, Context klar).  
- Storno-Sheet: Confirm-Ellipsis an tatsächlichen UI-Pfad koppeln.
