# Feature-Backlog (Konkurrenz-Analyse → Reisen)

Status: **Backlog** (F01, F03, F06, F09 umgesetzt; übrige Features geplant)  
Stand: 2026-08-30

## Zweck und Leitlinie

Reisen konsolidiert **bereits gebuchte** Multi-Anbieter-Reisen über Provider-Session-Sync in kanonische Domain-Entities — nicht über Inbox-Parser. Features aus TripIt, Tripsy, Voyager, Wanderlog, Tineo, KAYAK Trips, AwardWallet, Google Travel und Flighty werden nur übernommen, wenn sie diesen Store **vollständiger** oder **am Reisetag greifbarer** machen.

**Nicht übernehmen:** Inbox-OAuth, Mail-Forward-Cloud, KI-Reise generieren, Gruppen-Collaboration, Meilen/Loyalty, SAP Concur, öffentlicher iCal-Feed, eigener Live-Flugstatus.

Konkurrenz-Recherche (Marktvergleich, Datenquellen): Canvas `reise-apps-vergleich.canvas.tsx` und `reisen-feature-ergaenzungen.canvas.tsx` im Cursor-Projekt — hier nicht duplizieren.

---

## Übersicht

| ID | Feature | Status | Prio | Abhängigkeit |
|----|---------|--------|------|--------------|
| F01 | `BookingType.train` (Bahn) | implementiert | P1 | — |
| F02 | Check-in-Erinnerungen (Hotel + Flug) | geplant | P1 | — |
| F03 | Copy/Paste für Info- und Editor-Felder | umgesetzt | P2 | — |
| F04 | ICS/Text-Export einer Reise | geplant | P2 | — |
| F05 | Dokumente an der Buchung | geplant | P2 | eigene Spec |
| F06 | On-device Paste-Import | umgesetzt | P2 | F01, F05 optional |
| F07 | Next-up Widget / Live Activity | geplant | P3 | F02 |
| F08 | macOS-Suche und Typfilter | geplant | P3 | — |
| F09 | Vollständigkeitsanzeige (Gaps) | umgesetzt | P3 | — |
| F10 | Kartenansicht der Reise | bedingt | P3 | Geocoding zuverlässig |
| F11 | Zeitzonenwechsel in Timeline | bedingt | P3 | — |
| F12 | Wetter am Aufenthaltsort | bedingt | P3 | Koordinate |
| F13 | Kostensumme der Reise | bedingt | P3 | Preise vorhanden |
| F14 | Apple Wallet / PKPass | bedingt | P3 | F05 |
| F15 | Deep-Link zu Flighty / Airline | bedingt | P3 | — |
| X01 | Inbox-OAuth / Mail-Forward-Cloud | abgelehnt | — | — |
| X02 | KI-Reise generieren | abgelehnt | — | — |
| X03 | Echtzeit-Gruppenbearbeitung | abgelehnt | — | — |
| X04 | Meilen / Punkte / AwardWallet | abgelehnt | — | — |
| X05 | SAP Concur / Firmenreise | abgelehnt | — | — |
| X06 | Öffentlicher iCal-Feed-URL | abgelehnt | — | — |
| X07 | Eigener Live-Flugstatus / Gate | abgelehnt | — | — |

**Empfohlene Implementierungsreihenfolge:** F02 → F04 → F05 → F06 → F07–F08.

---

## Check-in-Erinnerungen: Was „Anlass neben Storno/Pre-Travel“ bedeutet

Das Notification-Framework fehlt **nicht**. Lokale Push-Erinnerungen laufen bereits für zwei fachliche **Anlässe** (`ReminderTarget`):

| Anlass | Code | Scheduler |
|--------|------|-----------|
| Stornofrist | `ReminderTarget.cancellationDeadline` | `LocalReminderScheduler.scheduleCancellationDeadlines` |
| Pre-Travel-Hinweise | `ReminderTarget.preTravelHints` | `LocalReminderScheduler+PreTravelHints` |

Hotel-**Check-in-Uhrzeiten** (`hotelCheckInMinutes`) werden bereits in **EventKit-Notizen** geschrieben (`CalendarTimelineTripCheckNotes`) — aber **nicht** als `UNUserNotification`.

**Check-in fehlt als dritter Anlass:** kein produktiver `ReminderTarget` für Check-in. `.gap` und `.custom` existieren (Tests/Seed), sind aber kein Nutzer-Feature.

### Zwei Check-ins (nicht vermischen)

| Anlass | Vorhandene Daten | Sinnvolle Erinnerung |
|--------|------------------|----------------------|
| Hotel-Anreise | `hotelCheckInMinutes` + `startAt` | Push am Check-in-Tag; Lead-Times analog Storno (7/3/1) oder am Tag selbst |
| Airline-Online-Check-in | Flug-`startAt` | Push typisch 24 h vor Abflug |

**F02** = ein Feature mit zwei Triggern, Settings-Toggle analog Storno. **Kein Dummy**, wenn Minuten oder `startAt` fehlen.

```
Buchungsdaten ──► Storno-Anlass ──► LocalReminderScheduler ──► UNNotification
              ├──► PreTravel-Anlass ──► LocalReminderScheduler ──► UNNotification
              ├──► Check-in-Anlass (fehlt)
              └──► EventKit-Notizen (Check-in-Zeit bereits)
```

---

## Geplante Features (Detail)

### F01 — `BookingType.train` (Bahn)

**Status:** implementiert (Spec: [`booking-type-train-impl-spec.md`](booking-type-train-impl-spec.md))

**Sinn:** DACH-Reisen ohne Bahn sind unvollständig. `.other` verschluckt Zugnummer, Bahnhof, Sitz — Transport-Gaps werden unscharf.

**Machbarkeit:** hoch. Muster: [`booking-type-activity-impl-spec.md`](booking-type-activity-impl-spec.md).

| Aspekt | Vorgehen |
|--------|----------|
| Domain | `case train` in `BookingType`; `rawValue` `"train"` |
| Persistenz | `SDBooking.bookingTypeRaw` — **keine** Schema-Migration |
| Zeitmodell | Wie Flug/Fähre in `BookingTimeNormalizeDispatch` (Punkt-zu-Punkt) |
| Labels | `L10n+Booking`, `BookingType+DetailFieldLabels`: Von/Nach Bahnhof, Abfahrt/Ankunft, Betreiber; `showsLocationFrom = true` |
| UI | `BookingEditor` (`BookingType.allCases`), Timeline, Details |
| Provider | Traveloka `TRAIN`/`TRAIN_GLOBAL` → `.train`; kein DB/ÖBB; Check24-Bahn ohne HAR |
| Tests | Analog `bookingType_carRental_*` in `BookingTypeTests` |

**Out of Scope:** Provider-Sync für Bahnportale; automatisches Parsen von Bahn-Tickets (→ F06).

**Folge-Spec:** `docs/dev/booking-type-train-impl-spec.md`

---

### F02 — Check-in-Erinnerungen

**Sinn:** Gleiche Infrastruktur wie Storno/Pre-Travel; unterwegs fehlt heute der Push zum Hotel-Check-in und zum Flug-Online-Check-in.

**Machbarkeit:** hoch (kleinster produktiver Gewinn).

| Aspekt | Vorgehen |
|--------|----------|
| Domain | Neuer `ReminderTarget` (z. B. `checkInHotel` / `checkInFlight` oder ein Target + Unterart) |
| Port | `ReminderScheduling` erweitern |
| Scheduler | `LocalReminderScheduler` + Aufruf aus `SyncStore.rebuildLocalSideEffects` |
| Settings | Toggle neben Notifications; Lead-Times wiederverwenden (Hotel) oder fest 24 h (Flug) |
| Guard | Keine Erinnerung ohne `startAt`; Hotel ohne `hotelCheckInMinutes` → nur Tages-Reminder oder weglassen |

**Out of Scope:** Live-Flugstatus, Gate-Änderungen (→ X07, ggf. F15).

**Folge-Spec:** Check-in-Reminder-Spec (noch anzulegen).

---

### F03 — Copy/Paste für Info- und Editor-Felder

**Status:** umgesetzt. Spec: [`f03-copy-paste-fields.md`](f03-copy-paste-fields.md).

**Sinn:** Am Counter ein Tap auf die Buchungsnr./PNR statt Textselektion; alle Info-Feldwerte ohne Markier-Akrobatik kopierbar; Editoren mit systemischem Cut/Copy/Paste.

| Aspekt | Vorgehen |
|--------|----------|
| Stufen | `standard` (Selektion + Kontextmenü) vs. `identifier` (Tap-to-Copy nur Buchungsnr./Zimmer-Code) |
| iOS | Eine List-Zeile pro Feld; URL: Tap öffnet, Kontextmenü kopiert |
| macOS | Inspector-Werte über `CopyableTextView` (Ablage → Kopieren ohne Markierung) |
| Editor | Natives TextField-Pasteboard; `textContentType` für Namen/URL; kein Trailing-Copy |
| SSOT | `StringPasteboard` + `FieldCopyKind` im Feldkatalog; kein `"Label: Wert"` in der Zwischenablage |

**Out of Scope:** Clipboard-Monitoring (→ F06); Share-Snapshot (→ F04); Copy-Buttons an jeder Standardzeile.

---

### F04 — ICS/Text-Export einer Reise

**Sinn:** Partner ohne Reisen-App brauchen eine Datei, nicht ein Konto.

**Machbarkeit:** hoch.

| Aspekt | Vorgehen |
|--------|----------|
| Format | ICS + Plain-Text der Trip-Timeline |
| UX | Share Sheet (iOS/macOS) |
| Kalender | **Kein** öffentlicher Feed-URL (→ X06); EventKit-Schreiben bleibt primär |

**Out of Scope:** Dynamischer Subscribe-Feed; PDF-Layout.

---

### F05 — Dokumente an der Buchung

**Sinn:** Ticket-PDF unterwegs; strukturierte Felder ersetzen das Original nicht.

**Machbarkeit:** mittel — **eigener Spec nötig**, nicht trivial.

| Aspekt | Vorgehen |
|--------|----------|
| Persistenz | Neues Cloud-Model `SDBookingAttachment` in `reisen-cloud` (mit Buchung über iCloud) |
| Schema | Hybrid-Store: nicht-versioniertes `Schema(ReisenSchemaV9.models)` — Add-Model-Pfad in Spec festlegen; kein stilles Wipe |
| Binärdaten | **Nicht** als großes SQLite-Attribut; Datei im Container + relative URL; CloudKit-Asset-tauglich |
| Typen | PDF, Bild; optional `pkpass` (→ F14) |
| UI | `fileImporter` an Buchungsdetail, Liste, Quick Look (iOS + Mac) |
| Privacy | `PrivacyInfo.xcprivacy`, Datenschutzerklärung um Anhänge/PII ergänzen |

**Out of Scope v1:** PDF automatisch parsen (→ F06); Server-Upload; Inbox-Anhänge.

**Folge-Spec:** Attachment-Spec (Schema + Privacy).

---

### F06 — On-device Paste-Import

**Status:** umgesetzt (inkl. Feature-Request per Mail, nicht-modaler Progress, Review-Fenster/Compose-Sheet).

**Sinn:** Abdeckung für Bahn, Restaurant, unbekannte OTAs **ohne** Inbox-OAuth. Ergänzt Provider-Sync, ersetzt ihn nicht.

**Machbarkeit:** mittel — harte Grenzen.

| Aspekt | Vorgehen |
|--------|----------|
| Plattform | Foundation Models; PCC wenn verfügbar, sonst On-Device; sonst disabled |
| Ausgabe | `ProviderBookingDraft`; Neu = `ProviderID.manual`, Ergänzen = bestehender Provider |
| Review | Pflicht im bestehenden `BookingEditor` vor Speichern |
| Fehler | Unsichere Felder leer; PCC-Fehler kein stiller Wechsel auf On-Device |
| Deaktiviert | Aktion sichtbar, Begründung wenn weder PCC noch On-Device |
| Abhängigkeit | F01 (`train`) zuerst, sonst ICE in `.other` |

**Out of Scope:** Postfach-Scan, Forward an Parser-Adresse, automatischer Upsert ohne Review; Drittanbieter-LLM (v2); Datei persistieren (F05).

**Spec:** [`docs/superpowers/specs/2026-08-28-paste-import-design.md`](../superpowers/specs/2026-08-28-paste-import-design.md)

---

### F07 — Next-up Widget / Live Activity

**Sinn:** Nächste Buchung und nächste Stornofrist sind Domain-Daten — Surface am Lock Screen.

**Machbarkeit:** mittel (WidgetKit, App Intents).

**Abhängigkeit:** F02 sinnvoll für konsistente Reminder-Targets.

**Out of Scope:** Live-Flugstatus.

---

### F08 — macOS-Suche und Typfilter

**Sinn:** iOS hat `.searchable` auf Reisen/Offen; macOS-Sidebar wird bei vielen Sync-Buchungen unübersichtlich.

**Machbarkeit:** hoch.

**Vorgehen:** Gleiche Query wie iOS; Filter über `BookingType` und `ProviderID` (SSOT Domain).

---

### F09 — Vollständigkeitsanzeige (Gaps)

**Status:** umgesetzt.

**Sinn:** Vorhandene Gap-Logik sichtbar machen (Vorbild: Voyager „planning percentage“).

**Umsetzung:** Inter-Booking-Lücken (nicht Rand-Gaps) in Trip-Übersicht, Reisen-Liste/Sidebar und Offen-Gruppierung „Kann Lücken füllen“. Kein Dummy-Prozent; `unknown`-Status nur als ruhige Detail-Caption.

---

## Bedingte Features (nicht Welle 1)

| ID | Feature | Bedingung |
|----|---------|-----------|
| F10 | Kartenansicht | Nur Punkte mit geocodeter Coordinate; fehlend = Lücke anzeigen, nicht raten |
| F11 | Zeitzonenwechsel in Timeline | Offset-Diff zwischen Buchungen |
| F12 | Wetter | WeatherKit, Opt-in, Coordinate nötig |
| F13 | Kostensumme | Summe vorhandener `BookingRateDetails`/Gap-Preise; fehlende Preise explizit |
| F14 | Apple Wallet | Nach F05; PKPass nur wenn Datei passt |
| F15 | Deep-Link Flighty/Airline | Analog `ProviderNativeApp`; kein eigener Tracker |

---

## Abgelehnte Features (bewusst nicht)

| ID | Feature | Begründung |
|----|---------|------------|
| X01 | Inbox-OAuth / Mail-Forward | Widerspricht Privacy, lokalem SSOT, App-Store-Risiko; macht Reisen zu TripIt |
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
| Gaps + Deep-Links + Vollständigkeits-UI (F09) | Voyager flagged nur Lücken | Kern halten |
| Pre-Travel Hints, Passagiere, Gepäck | Freitext in Mails | Kein generisches „Tipps“-Feature |
| EventKit schreiben | iCal-Feed-URL | F04 Datei-Share, kein Feed (X06) |
| Offen-Tab / Zuordnung | TripIt merged nach Datum | Beibehalten |

---

## Follow-up Specs (nach Backlog-Freigabe)

1. [`booking-type-train-impl-spec.md`](booking-type-train-impl-spec.md) — implementiert
2. Check-in-Reminder-Spec — noch anzulegen
3. Attachment-Spec (Schema + Privacy) — noch anzulegen
4. [`../superpowers/specs/2026-08-28-paste-import-design.md`](../superpowers/specs/2026-08-28-paste-import-design.md) — F06 Spec; Plan: [`../superpowers/plans/2026-08-28-paste-import.md`](../superpowers/plans/2026-08-28-paste-import.md)
