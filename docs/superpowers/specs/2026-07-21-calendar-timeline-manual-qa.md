# Kalender-Timeline – Manuelle Abnahme (EventKit + Event-Identität)

## Ziel
Nach dem Sync sollen Kalender-Einträge für Trip/Flight/Hotel (je nach Toggle) korrekt erstellt, aktualisiert und bei Toggle-Aus gelöscht werden.

## Vorbereitung
1. In den App-Einstellungen → „Apple Kalender“ aktivieren (Picker für Kalender/Reminder-Liste optional, aber für EventKit erforderlich).
2. MapKit-Address-Auflösung ist best-effort und kann je nach Treffer/Latenz einige Sekunden dauern.
3. Mindestens eine Reise mit:
   - Hotel-Buchung(en) (mit `Bestätigungscode` und `Check-in/Check-out`-Minuten wenn möglich)
   - mindestens einem Flug (Abflug/Ankunft-Zeiten)

## Test 1: Reisebeginn/-ende (Toggle: Reisezeiten)
1. Setze Toggles:
   - „Reisebeginn/-ende eintragen“ = an
   - „Flugabflug/-ankunft eintragen“ = aus
   - „Hotelaufenthalte eintragen“ = aus
2. Sync auslösen.
3. In Kalender.app pro Trip:
   - Es gibt **2 ganztägige** Termine: „Reisebeginn: …“ und „Reiseende: …“
   - In den **Notizen** der Termine stehen Check-in/-out-Zeiten, falls Hotel-Minuten bekannt sind.
   - Location ist vorhanden, wenn eine Hoteladresse aufgelöst/gespeichert werden konnte.

## Test 2: Abflug/Ankunft (Toggle: Flugzeiten)
1. Toggles:
   - „Reisebeginn/-ende“ = aus
   - „Flugabflug/-ankunft“ = an
   - „Hotelaufenthalte“ = aus
2. Sync auslösen.
3. Pro Flug:
   - Es gibt **2 zeitbezogene** Termine: „Abflug: …“ und „Ankunft: …“
   - Der Termin hat eine **Location** (Adressauflösung, wenn Daten vorhanden waren).
   - Der Termin enthält die Buchungs-URL (EventKit `url`), sowie Booking-Meta in den Notizen (z. B. Bestätigungscode).

## Test 3: Hotelaufenthalte (Toggle: Hotelaufenthalte)
1. Toggles:
   - „Reisebeginn/-ende“ = aus
   - „Flugabflug/-ankunft“ = aus
   - „Hotelaufenthalte“ = an
2. Sync auslösen.
3. Für **jede einzelne Hotelbuchung**:
   - Es gibt **einen eigenen** ganztägigen Termin „Hotel: …“
   - Notizen enthalten mindestens:
     - „Hotel: …“
     - „Bestätigung: …“ (wenn vorhanden)
     - „Check-in: HH:mm“ und/oder „Check-out: HH:mm“ (wenn Minuten gesetzt sind)
   - Location ist vorhanden, wenn Adresse aufgelöst/gespeichert wurde.

## Test 4: Update ohne Duplikate
1. Setze alle drei Toggles an.
2. Sync auslösen (Baseline).
3. Danach ändere eine relevante Buchungsmetrik (z. B. Bestätigungscode durch erneuten Provider-Sync, oder Hotel-Offset/Zeiten).
4. Nochmal syncen.
5. Erwartung:
   - pro Rolle/Owner wird **aktualisiert**, nicht dupliziert (Event-Identität über persistierte `SDCalendarEventLink`).

## Test 5: Toggle-Aus löscht zugehörige Events
1. Setze alle Toggles an, syncen.
2. Dann z. B.:
   - „Flugabflug/-ankunft“ = aus (nur Flug-Rollen entfernen)
3. Sync erneut auslösen.
4. Erwartung:
   - „Abflug: …“ / „Ankunft: …“ Termine verschwinden
   - Reise- und Hotel-Termine bleiben (sofern deren Toggles weiterhin aktiv sind).

## Test 6: Stornofristen (EventKit EKEvent + EKReminder) + leadTimes
1. Settings → „Apple Kalender“ aktivieren (EventKit).
2. Settings → „Kalender-Strategie“ auf „Pro Reise (Reisenname)“ stellen.
3. Einstellungen → „Vorläufe“ (leadTimesDays) so konfigurieren, dass mehrere Tage vorkommen (z. B. `7,3,1`).
4. Sync auslösen.
5. Pro Trip (Kalender heißt jeweils `trip.title`):
   - Es gibt für jede kostenlose Stornofrist mehrere Einträge („Stornofrist: …“) entsprechend den konfigurierten Vorlauf-Tagen.
   - In den **Notizen** jedes Eintrags steht die „Deadline:“ und die „Lead:“ Information.
6. Erwartung Update/No-Duplicate:
   - leadTimesDays änder (z. B. `7,3,1` → `7,1`).
   - Sync erneut auslösen.
   - Erwartung: Einträge für entfernte Lead-Tage verschwinden, verbleibende Einträge werden aktualisiert (keine Duplikate).

## Test 7: Storno Cleanup beim Buchungs-Prune (Buchung/Deadline weg)
1. Vorher: Mindestens ein Trip mit einer kostenlosen Stornofrist.
2. Sync auslösen und bestätigen, dass Storno-Einträge im Trip-Kalender existieren.
3. Buchung so entfernen/prunen, dass die zugehörige CancellationDeadline wegfällt (z. B. erneuter Sync, der die Buchung entfernt).
4. Nächsten Sync auslösen.
5. Erwartung:
   - Storno-Einträge (Event + Reminder) des entfernten Booking verschwinden im betreffenden Trip-Kalender/Reminder-Liste.

