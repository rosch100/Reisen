# Kalender-Timeline (EventKit) mit Event-Identität – Design

## Ziel
Für alle Reisen sollen – konfigurierbar in den Einstellungen – Kalender-Einträge in Apples Kalender- und Reminder-Umgebung erzeugt werden:

- **Reisebeginn/-ende** (All-Day)
- **Abflug/Ankunft** (zeitbezogen)
- **Hotelaufenthalte** (All-Day, ein Termin pro Hotelbuchung)

Zusätzlich sollen – wenn bekannt – **Adresse/Ort** sowie ein **Link auf die Buchung** in Termin-Location, URL und/oder Notizen erscheinen.

## Nicht-Ziele
- Eigene **Check-in/-out-Punkttermine** (nur in Notizen mit Uhrzeit-Informationen, wenn verfügbar)
- Storno-Deadline-Reminders/Events: bleibt eigener, bestehender EventKit-/Notification-Pfad
- Keine Web-Scraping-basierten Ortsauflösungen; nur vorhandene Daten + MapKit-Geocoding/-Suche

## Bestehender Stand (Ist)
- `LocalEventKitBridge.syncTripTimelineEntries(...)` erzeugt aktuell Termine über Titel-/Zeit-Heuristik und setzt keine Location/URL/Notes.
- `SettingsView` enthält bereits Picker für Kalender- und Reminder-Listen sowie Toggles für Reise-/Flugzeiten.
- Datenmodell `Booking` enthält u. a. `locationFromAddress`, `locationToAddress`, `externalUrl`, Hotel-Offset und Check-in/-out-Minuten.

## Gesamtkonzept
Die Timeline-Sync wird von „Heuristik-Upset über Titel“ zu „Identitätsbasierter Upsert/Delete“ umgebaut.

### Rolle des neuen Event-Identity-Modells
Ein neu eingeführtes Persistenzmodell speichert pro logischem Termin eine stabile Zuordnung zur EventKit-Entität:

- **Wer / was erzeugt den Termin?** (Trip oder Booking)
- **Welche Rolle?** (z. B. `tripStart`, `flightDeparture`, `hotelStay`)
- **Welche EventKit-IDs?** (intern `eventIdentifier` / optional `calendarItemExternalIdentifier`)

So kann die Bridge in nachfolgenden Syncs Termine gezielt aktualisieren oder bei Toggle-aus/Entfernung löschen, ohne auf Titel zu vertrauen.

## Event-Rollen & Terminregeln

### Reisebeginn/-ende
- Toggle: bestehend (`calendarTripTimesEnabled`)
- Typ: **All-Day**
- Start/Ende: ganztägig je `Trip.startDate` bzw. `Trip.endDate`
- Ort: erste sinnvolle Hoteladresse aus der zugehörigen Reise (falls bekannt), sonst leer (Location wird nicht erzwungen)
- Notes: Check-in/-out-Zeiten aus Hotels nur dann, wenn Minuten bekannt sind (sonst keine Uhrzeit)

### Abflug / Ankunft
- Toggle: bestehend (`calendarFlightTimesEnabled`)
- Typ: zeitbezogen mit 1h-Enddauer (bestehende Konvention bleibt; Fokus liegt auf der Zeiterfassung)
- Ort: Abflug-Adresse / Ankunft-Adresse aus Buchungsdaten (siehe Address-Regeln)
- URL: `booking.externalUrl` (falls vorhanden)
- Notes: ergänzende Meta-Informationen (z. B. Provider-Titel, Confirmation Code falls vorhanden, keine Dummywerte)

### Hotelaufenthalt
- Toggle: **neu** (z. B. `calendarHotelStaysEnabled`)
- Typ: **All-Day**
- Zeit: pro Hotelbuchung ein Termin über den Aufenthalt (`booking.startAt` bis `booking.endAt`, tagesgenau)
- Ort: Hoteladresse (siehe Address-Regeln)
- URL: `booking.externalUrl` (falls vorhanden)
- Notes:
  - Hotelname/Titel, Confirmation Code (falls vorhanden)
  - Check-in/-out Uhrzeiten, falls `hotelCheckInMinutes` / `hotelCheckOutMinutes` gesetzt sind
  - ggf. (falls relevant) weitere bekannte Metadaten

## Adresse & Buchungslink

### SSOT: vorhandene Felder zuerst
Für Location werden primär die Buchungsfelder genutzt:

- `locationFromAddress` / `locationToAddress`
- Fallbacks: `locationFrom` / `locationTo` als Such-Query
- Link: `externalUrl` (falls vorhanden)

### MapKit-Auflösung (nur wenn Adresse fehlt)
Wenn eine benötigte Adresse in der Buchung noch nicht vorhanden ist:

1. Der Sync erstellt aus vorhandenen Feldern eine Suchanfrage (Ort/IATA/Name).
2. MapKit versucht, eine best-effort Address zu finden.
3. Der Treffer wird in der Buchung **persistiert** (`location*Address`) und im Termin verwendet.

### Kein stilles Fallbacken
Wenn MapKit keinen Treffer liefert, wird kein Dummy-Ort eingesetzt.
Der Termin wird ohne Location synchronisiert; Sync schlägt nicht still fehl.

## Identitätsbasierter Sync (Upsert/Delete)

### Upsert-Schlüssel
Für jedes Event wird ein logischer Schlüssel gebildet:

- `role` (`tripStart`, `tripEnd`, `flightDeparture`, `flightArrival`, `hotelStay`)
- `ownerTripID` und/oder `ownerBookingID`

Dieser Schlüssel wird in `CalendarEventLink` persistent gespeichert, zusammen mit EventKit-IDs.

### Delete-Regeln
Beim nächsten Sync gilt:

- Toggle aus → entferne alle Termin-Links der betroffenen Rollen (und lösche zugehörige EventKit Events).
- Buchung aus Reise entfernt / Trip gelöscht → entferne zugehörige Termin-Links und lösche Events.

### Umgang mit externen Änderungen
Wenn ein Event in Kalender-App entfernt wurde (oder EventKit nicht mehr verfügbar ist):
- Termin-Link bleibt nicht als „wahr“ bestehen; die Bridge versucht beim nächsten Sync erneut anzulegen (ohne stilles Weglassen).

## Settings & HIG (UX/Best Practices)
- Picker für Kalender-/Reminder-Listen bleibt bestehen; Option „Neu anlegen…“ bleibt bestehen.
- Neue Hotel-Toggle erhält klaren Text und `.help` (disabled ohne EventKit-Access).
- Bei Ladefehlern im Kalender-/Reminder-Picker: sichtbare Fehlermeldung, keine stillen Fallbacks.
- Privacy: `Info.plist`-Usage-Descriptions für Kalender **und** Reminder Access (Full Access).
- UI-Strings in Deutsch; keine kryptischen Begriffe.

## Teststrategie (kurz)
- Domain-Tests:
  - Termin-Erzeugung: All-Day vs. zeitbezogen
  - Notes-Building: Uhrzeiten nur bei vorhandenen Minuten
  - URL/Location: nur wenn Daten vorhanden (keine Dummywerte)
- Daten-/Repository-Tests:
  - Upsert/Delete-Semantik von `CalendarEventLink`
- Platform-Tests:
  - MapKit-Auflösung über Fake-Resolver (keine Live-Abhängigkeit)
- Kein EventKit-Integrationstest in CI erzwingen (AppKit-/EventKit abhängig).

## Metriken / Akzeptanzkriterien
- Bei Aktivierung aller relevanten Toggles werden für eine Reise:
  - Reisebeginn/-ende (All-Day)
  - Abflug/Ankunft (zeitbezogen)
  - jede Hotelbuchung als eigener All-Day Termin
  erzeugt.
- Termine enthalten Location (wenn Adresse bekannt oder aufgelöst) und Notes/URL mit Meta-Infos (ohne Dummywerte).
- Toggle-aus löscht die zugehörigen Events (und Links) aus der Kalender-App.

