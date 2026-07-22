# Manuelle Buchungen anlegen & bearbeiten (macOS HIG)

## Ziel

Nutzer können zu einer Reise **beliebige Buchungen manuell anlegen und bearbeiten**. Alle Felder, die auch bei synchronisierten Buchungen existieren und in der Detailansicht sichtbar sind, sind editierbar. Neue/geänderte Buchungen erscheinen in der Timeline **sortiert nach Datum** (bestehende Sortierung über `startAt`).

## HIG- / Best-Practice-Entscheidungen

| Thema | Entscheidung | Begründung |
|--------|--------------|------------|
| Bearbeiten | Rechte Detailspalte, **Bearbeiten → Abbrechen/Sichern** | Inspector-Muster (Kontakte/Erinnerungen): Selektion → Eigenschaften rechts, modelless |
| Anlegen | Dieselbe Detailspalte (Inspector), kein Modal-Sheet | Breite der Spalte nutzbar, Form scrollt, Cmd+Q bleibt frei; Sheet war auf macOS SwiftUI unzuverlässig |
| Form-UI | **Eine** gemeinsame Form-Komponente | SSOT, keine doppelte Feldlogik |
| Speichern | Explizit (kein Autosave), sticky Fußleiste | Viele optionale Felder; Sync-Buchungen nicht versehentlich ändern |
| Darstellung | `Form` + `.formStyle(.grouped)`, Abschnitte | macOS-Standard für strukturierte Eigenschaften |

## UI-Verhalten

### Einstiege

1. **Neue Buchung** (bei ausgewählter Reise)
   - Toolbar der mittleren Spalte: „Buchung hinzufügen…“
   - Rechte Detailspalte zeigt `BookingEditorForm` im Modus `create` (gleiche UI wie Bearbeiten), vorbefüllt mit sinnvollen Defaults (heute / Trip-Start).
2. **Buchung bearbeiten**
   - Rechte Detailspalte: Button „Bearbeiten“ (nur bei selektierter Buchung).
   - Wechselt die Detailspalte in den Edit-Modus derselben Form (`BookingEditorForm`).
   - „Sichern“ speichert und kehrt zur Leseansicht zurück; „Abbrechen“ verwirft lokale Edits.
3. **Gap** bleibt unverändert über `GapEditorSheet`.

### Form-Abschnitte (SSOT-Felder)

Sichtbarkeit typabhängig (`BookingType`).

**Allgemein (immer)**

- Titel
- Typ (`flight` / `hotel` / `ferry` / `other`)
- Status (`confirmed` / `cancelled` / `unknown`)
- Provider: bei Create-Manual fest `manual`; bei Sync-Buchung Anzeige read-only (nicht umbenennen)
- Bestätigungscode
- External URL (optional)
- Start / Ende (`DatePicker` date+time)
- Ort von / Ort nach

**Hotel** (wenn Typ Hotel)

- Check-in / Check-out (Minuten seit Mitternacht → bestehende `hotelCheckInMinutes` / `hotelCheckOutMinutes`)
- Hotel-Offset (Sekunden), falls in Detailansicht geführt

**Flug** (wenn Typ Flug)

- Abflug-/Ankunft-Offset (Sekunden), falls in Detailansicht geführt

**Tarif / RateDetails** (optional, Unterform)

- Preis, Währung
- Hotel: Zimmerkategorie, Verpflegung (`BookingBoardType`), Frühstück, Gäste, Zimmer
- Flug: Airline, Passagiere, Gepäck-Info

**Stornofristen** (Liste)

- Einträge hinzufügen/entfernen/bearbeiten: Datum/Zeit, Policy-Text, kostenlos ja/nein, Gebühr (optional), strict

**Nicht editierbar (System)**

- `id`, `lastSyncedAt`, `rawPayloadFingerprint`, `timesSourceFingerprint`, `timesNormalized` (werden bei manuellem Speichern konsistent gesetzt/gelöscht, nicht als UI-Felder)

### Leseansicht rechts

- Bestehende Detailanzeige bleibt für den View-Modus.
- Zusätzlich: „Bearbeiten“; bei manuellen Buchungen optional „Löschen…“ (Bestätigungsdialog) neben „Von Reise entfernen“.

### Einsortierung

- Keine separate Sortier-UI: Timeline nutzt weiter `startAt` (und bestehende Gap-Logik).
- Speichern aktualisiert SwiftData → `@Query` / Trip-Relationship → Liste sortiert sich neu; Selektion bleibt auf derselben `booking.id`.

## Daten / Persistenz

### Provider `manual`

- Neuer stabiler `ProviderID.manual` (`rawValue: "manual"`).
- Manuelle Buchungen: `provider == .manual`.
- `externalUrl`: bei Create synthetisch und stabil, z. B. `reisen://manual/<uuid>`, damit Repository-Upsert/Identity greift und Sync anderer Provider sie nicht als „fremd“ löscht.
- `SyncProviderBookings.deleteProviderBookings` betrifft nur den syncenden Provider → Manual-Buchungen bleiben erhalten.

### Sync vs. lokale Edits (v1)

- **Manual:** Sync rührt sie nicht an.
- **Sync-Buchungen:** Lokale Edits sind erlaubt und werden persistiert. Beim **nächsten Sync desselben Providers** überschreibt der Upsert die Provider-Felder wie bisher (kein Field-Pinning in v1). Die Reise-Zuordnung (`trip`) bleibt wie im bestehenden Upsert-Verhalten geschützt, sofern bereits so implementiert.
- UI-Hinweis im Edit-Modus bei Sync-Buchungen (Footer/Hilfe): „Änderungen können beim nächsten Sync überschrieben werden.“

### Speichern

- Create: neues `SDBooking` anlegen, `trip` setzen, optional `SDBookingRateDetails` / `SDCancellationDeadline`s, `modelContext.save()`.
- Edit: bestehendes Modell mutieren (gleiche Beziehungen), speichern.
- Validierung: Titel nach Trim nicht leer; `endAt >= startAt`; Preisparse wie Gap-Editor (de_DE).

## Komponenten / Verantwortlichkeiten

| Komponente | Rolle |
|------------|--------|
| `BookingEditorForm` | SSOT-Form: Bindings auf Edit-Model / Draft; typabhängige Sections |
| `BookingEditorDraft` | Werttyp mit allen editierbaren Feldern + Mapping von/nach `SDBooking` |
| `BookingEditorSheet` | Create-Sheet (Titel, Form, Abbrechen/Sichern), analog `TripEditorSheet` |
| `BookingDetailPanel` | View-Modus + Umschalten Edit-Modus; bettet `BookingEditorForm` ein |
| `TripDetailView` / Toolbar | Einstieg „Buchung hinzufügen…“ |
| `ProviderID` | `.manual` |
| Tests | Draft-Mapping, Validierung `end >= start`, Manual-URL-Stabilität |

## Nicht in diesem Scope

- Field-Pinning / Merge-Strategien gegen Sync (später)
- Foto/Anhänge
- Drag-and-drop-Sortierung unabhängig vom Datum
- Globale „alle Buchungen“-Bearbeitung außerhalb einer Reise (Create immer im Trip-Kontext; offene Buchungen können später analog folgen)

## Smoke-Verification (nach Implementierung)

- Neue manuelle Hotel-Buchung anlegen → erscheint chronologisch in der Liste und in der Sidebar unter der Reise.
- Bearbeiten in der Detailspalte → Fertig → Werte sichtbar; App-Neustart behält Daten.
- Opodo/Check24-Sync löscht manuelle Buchungen nicht.
- Flug-Felder nur bei Typ Flug; Hotel-Felder nur bei Typ Hotel.
