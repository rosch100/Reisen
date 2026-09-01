# Feature-Backlog (Konkurrenz-Analyse → Reisen)

Status: **Backlog** (F02/F04/F05/F07/F14/F15 zurückgestellt; F08, F16/F17, F20–F24 aktiv; F10–F12 bedingt; F01/F03/F06/F09/F13/F18/F19 umgesetzt)
Stand: 2026-09-01

## Zweck und Leitlinie

Reisen konsolidiert **bereits gebuchte** Multi-Anbieter-Reisen über Provider-Session-Sync in kanonische Domain-Entities — nicht über Inbox-Parser. Features aus TripIt, Tripsy, Voyager, Wanderlog, Tineo, KAYAK Trips, AwardWallet, Google Travel und Flighty werden nur übernommen, wenn sie diesen Store **vollständiger** oder **am Reisetag greifbarer** machen.

**Nicht übernehmen:** Inbox-OAuth, Mail-Forward-Cloud, KI-Reise generieren, Gruppen-Collaboration, Meilen/Loyalty, SAP Concur, öffentlicher iCal-Feed, eigener Live-Flugstatus.

Konkurrenz-Recherche: Canvas `reise-apps-vergleich.canvas.tsx` und `reisen-feature-ergaenzungen.canvas.tsx` im Cursor-Projekt — hier nicht duplizieren.
Interaktive UX-ToDos: Canvas `feature-todo-liste.canvas.tsx`.

---

## Übersicht (offen)

| ID | Feature | Status | Prio | Abhängigkeit |
|----|---------|--------|------|--------------|
| F02 | Check-in-Erinnerungen (Hotel + Flug) | zurückgestellt | P1 | — |
| F04 | ICS/Text-Export einer Reise | zurückgestellt | P2 | — |
| F05 | Dokumente an der Buchung | zurückgestellt | P2 | eigene Spec |
| F07 | Next-up Widget / Live Activity | zurückgestellt | P3 | F02 |
| F08 | macOS-Suche und Typfilter | geplant | P3 | — |
| F10 | Kartenansicht der Reise | bedingt | P3 | Geocoding zuverlässig |
| F11 | Zeitzonenwechsel in Timeline | bedingt | P3 | — |
| F12 | Wetter am Aufenthaltsort | bedingt | P3 | Koordinate |
| F14 | Apple Wallet / PKPass | zurückgestellt | P3 | F05 |
| F15 | Deep-Link zu Flighty / Airline | zurückgestellt | P3 | — |
| F16 | Drag/Drop Buchung ↔ Reise | geplant | P1 | — |
| F17 | Drop-Zone „Neue Reise“ | geplant | P2 | F16 |
| F20 | Undo nach Zuordnung/Lösung | geplant | P3 | F16/F19 |
| F21 | Datumsfenster-Warnung beim Drop | geplant | P2 | F16 |
| F22 | Reisen zusammenführen | geplant | P3 | — |
| F23 | Buchungs-Notiz / Memo | geplant | P3 | eigene Spec |
| F24 | Duplikat-Hinweis über Provider | geplant | P3 | eigene Spec |
| X01–X07 | abgelehnte Ideen | abgelehnt | — | siehe unten |

**Zurückgestellt:** F02, F04, F05, F07, F14, F15.
**Aktive Reihenfolge:** F16 → F21 → F17 → F20; danach F08; F22–F24 später.

---

## Umgesetzt (Archiv)

Nur Referenz — Specs bleiben, keine Backlog-Details mehr.

| ID | Feature | Spec / Hinweis |
|----|---------|----------------|
| F01 | `BookingType.train` | [`booking-type-train-impl-spec.md`](booking-type-train-impl-spec.md) |
| F03 | Copy/Paste Info- und Editor-Felder | [`f03-copy-paste-fields.md`](f03-copy-paste-fields.md) |
| F06 | On-device Paste-Import | [`../superpowers/specs/2026-08-28-paste-import-design.md`](../superpowers/specs/2026-08-28-paste-import-design.md) |
| F09 | Vollständigkeitsanzeige (Gaps) | Inter-Booking-Lücken in Trip-/Offen-UI |
| F13 | Kostensumme der Reise | [`../superpowers/specs/2026-09-01-trip-cost-currency-design.md`](../superpowers/specs/2026-09-01-trip-cost-currency-design.md) |
| F18 | Mehrfachauswahl + Sammel-Zuordnung | `AssignBookingsSheet` mit Batch-Zuordnung |
| F19 | Kontextmenü Zuordnen / Lösen | macOS-Kontextmenüs für offene und zugeordnete Buchungen |

---

## Aktive Features (Detail)

### F08 — macOS-Suche und Typfilter

**Sinn:** iOS hat `.searchable` auf Reisen/Offen; macOS-Sidebar wird bei vielen Sync-Buchungen unübersichtlich.

**Machbarkeit:** hoch. Gleiche Query wie iOS; Filter über `BookingType` und `ProviderID` (SSOT Domain).

---

### F16 — Drag/Drop Buchung ↔ Reise

**Sinn:** Zuordnung heute über Menüs/Sheets; Drag/Drop macht Offen↔Reise greifbarer — Domain-Port existiert bereits (`TripRepository.assignBooking`).

**Machbarkeit:** hoch (UI + Transferable/UTType; Persistenz fertig).

| Fluss | Start | Ziel | Aktion |
|-------|-------|------|--------|
| 1 | Offene Buchung | Reise (Sidebar-Zeile) | `assignBooking(id, tripID)` |
| 2 | Buchung in Reise | „Offene Buchungen“ | `assignBooking(id, nil)` |

**Drag-Start:** linke Spalte (Buchungszeile) **oder** mittlere Spalte (Liste/Timeline) — gleiche Payload (`bookingID`).

**Guards:** Ungültige Drop-Ziele ablehnen (kein stilles Zuordnen). Datumsfenster → F21.

**Out of Scope v1:** Multi-Drag (→ F18); Drop auf „Neue Reise“ (→ F17); iOS-Phone ohne Split-View (iPad/macOS zuerst).

---

### F17 — Drop-Zone „Neue Reise“

Offene Buchung(en) auf explizite Zone → `TripEditor` mit Seed (`OpenBookingCreateTripAction`). Speichern erst nach Bestätigung.

### F20 — Undo nach Zuordnung/Lösung

Kurzzeitiges Undo mit gespeicherter vorheriger `tripID`; Timeout kommunizieren.

### F21 — Datumsfenster-Warnung beim Drop

`TripBookingDateWindow`: außerhalb → Confirm-Sheet, kein stiller Fallback auf Offen.

### F22 — Reisen zusammenführen

Batch-assign auf Zielreise + Quellreise löschen nach Bestätigung; Side Effects über Rebuild.

### F23 — Buchungs-Notiz / Memo

Optionales Freitextfeld; Privacy prüfen; eigene Spec.

### F24 — Duplikat-Hinweis über Provider

Heuristik Datum/Ort/Typ; Nutzer entscheidet; kein Auto-Dedup.

---

## Zurückgestellte Features

Bewusst nicht in der aktiven Welle; Specs/Ideen bleiben gültig.

| ID | Feature | Hinweis |
|----|---------|---------|
| F02 | Check-in-Erinnerungen | Spec noch offen; Kontext unten |
| F04 | ICS/Text-Export | ICS + Plain-Text Share; kein Feed-URL (→ X06) |
| F05 | Dokumente an der Buchung | `SDBookingAttachment` + Privacy; Attachment-Spec später |
| F07 | Next-up Widget / Live Activity | hängt an F02 |
| F14 | Apple Wallet / PKPass | hängt an F05 |
| F15 | Deep-Link Flighty/Airline | Analog `ProviderNativeApp`; kein eigener Tracker |

### F02 — Kontext: Check-in als dritter Reminder-Anlass

Lokale Push laufen bereits für Storno (`cancellationDeadline`) und Pre-Travel (`preTravelHints`). Hotel-Check-in-Minuten stehen in EventKit-Notizen, aber **nicht** als `UNUserNotification`.

| Anlass | Daten | Erinnerung |
|--------|-------|------------|
| Hotel-Anreise | `hotelCheckInMinutes` + `startAt` | Push am Check-in-Tag; Lead-Times analog Storno |
| Airline-Online-Check-in | Flug-`startAt` | typisch 24 h vor Abflug |

**Kein Dummy**, wenn Minuten oder `startAt` fehlen. Folge-Spec bei Reaktivierung.

### F04 / F05 / F07 (Kurz)

- **F04:** Share Sheet ICS + Plain-Text der Trip-Timeline; EventKit bleibt primär.
- **F05:** Cloud-Model + Datei im Container (kein großes SQLite-Blob); PDF/Bild; optional pkpass → F14.
- **F07:** WidgetKit / Live Activity aus Domain-„nächste Buchung / Stornofrist“.

---

## Bedingte Features (nicht Welle 1)

| ID | Feature | Bedingung |
|----|---------|-----------|
| F10 | Kartenansicht | Nur Punkte mit geocodeter Coordinate; fehlend = Lücke anzeigen, nicht raten |
| F11 | Zeitzonenwechsel in Timeline | Offset-Diff zwischen Buchungen |
| F12 | Wetter | WeatherKit, Opt-in, Coordinate nötig |

---

## Abgelehnte Features (bewusst nicht)

| ID | Feature | Begründung |
|----|---------|------------|
| X01 | Inbox-OAuth / Mail-Forward | Privacy, lokaler SSOT, App-Store-Risiko |
| X02 | KI-Reise generieren | Planer, nicht Konsolidierer; Halluzination vs. no-fallbacks |
| X03 | Gruppen-Collaboration | Anderes Produkt; CloudKit Sharing |
| X04 | Meilen / Loyalty | Eigenes Produkt (AwardWallet) |
| X05 | SAP Concur | Enterprise, nicht Zielgruppe |
| X06 | Öffentlicher iCal-Feed | Leak-Vektor; EventKit + F04 Share reichen |
| X07 | Live-Flugstatus | Flighty/TripIt Pro; Reisen = Store, nicht Radar |

---

## Was Reisen bereits besser kann (nicht nachbauen)

| Reisen hat | Konkurrenz | Folge |
|------------|------------|-------|
| Provider-Session-Sync (7 OTAs) | Mail-Parser | Nicht durch Inbox ersetzen |
| `CancellationDeadline` + Notifications | Kaum modelliert | Kern halten; F02 analog erweitern |
| Gaps + Vollständigkeits-UI | Voyager flagged nur Lücken | Kern halten |
| Pre-Travel Hints, Passagiere, Gepäck | Freitext in Mails | Kein generisches „Tipps“-Feature |
| EventKit schreiben | iCal-Feed-URL | F04 Datei-Share, kein Feed (X06) |
| Offen-Tab / Zuordnung | TripIt merged nach Datum | Beibehalten; F16 als UX darauf |
| Reiseübergreifende Tages-Überschneidungen (Typ-Occupancy, Caption macOS+iOS) | Oft nur Intra-Trip / Text-only | Kern halten; F24 bleibt Provider-Duplikat (geplant) |
| Bahn-Typ, Paste-Import, Copy-Felder | — | Umgesetzt (Archiv) |

---

## Follow-up Specs

1. Drag/Drop-Zuordnung-Spec (**F16**) — nächste aktive Spec
2. Check-in-Reminder-Spec — zurückgestellt (F02)
3. Attachment-Spec (Schema + Privacy) — zurückgestellt (F05)
