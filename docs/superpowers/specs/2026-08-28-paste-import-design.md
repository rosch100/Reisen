# Paste-Import (F06) — Design

Datum: 2026-08-28  
Status: freigegeben (Brainstorming; P1-Judge-Korrekturen)  
Backlog: [feature-backlog.md](../../dev/feature-backlog.md) F06  
Muster: manueller `BookingEditor`; Match über dieselben **Indexe** wie Sync (`SyncBookingMatchIndex`), nicht über `SyncBookingMatchLookup.match`

## Ziel

Der Nutzer fügt Bestätigungsmaterial (Text, Bild, PDF) ein. Die App extrahiert Buchungskandidaten on-device oder über Apple Private Cloud Compute, der Nutzer wählt und prüft jede Buchung im bestehenden `BookingEditor`, erst dann wird gespeichert. Das ergänzt Provider-Sync für Bahn, Restaurant und unbekannte OTAs — ohne Inbox-OAuth.

## Begriffe (SSOT)

| Begriff | Bedeutung |
|---|---|
| **Quelle** (`PasteImportSource`) | Ephemeres Material: Text, Bild-Bytes oder PDF-Bytes. Wird nicht als Anhang persistiert (F05 bleibt getrennt). |
| **Rohextrakt** (`PasteImportExtraction`) | Adapter-Ausgabe: optionale Felder. Unbekanntes Typ-Label → `bookingType == nil` (kein `.other`). |
| **Draft** (`PasteImportDraft`) | Nach Filter: `bookingType` + `startAt` Pflicht; `endAtIsPlaceholder` wenn `endAt` fehlte. |
| **Resolver** (`PasteImportModelResolver`) | Wählt genau eine Modellstufe aus Availability *vor* dem Lauf. Sieht keine Lauf-Fehler. |
| **Modellstufe** | `privateCloudCompute` \| `onDevice` \| `unavailable`. Kein Drittanbieter in v1. |
| **Match** (`PasteImportMatch`) | `unique(Booking)` \| `none` \| `ambiguous`. Dieselben Indexe wie Sync. |
| **Kandidat** (`PasteImportCandidate`) | Draft + Match. `isErgaenzen` = unique; `showsAmbiguousHint` = ambiguous. |
| **Neu** | `none` oder `ambiguous` → `ProviderID.manual`, Editor Create. |
| **Ergänzen** | `unique` → bestehender Provider bleibt, Editor Edit, nur Lücken. |
| **Lücke** | Optionales Feld der bestehenden Entity ist `nil` / leer. |
| **Merge** | Nur `PasteImportMerger.fillingGaps(on:from:)` auf Domain-`Booking`. |

**Explizit verworfen:** `SyncBookingMatchLookup.match` (unique und none ununterscheidbar; URL last-write). `SyncBookingDraftApplier`. Zweiter Gap-Fill auf `BookingEditorDraft`-Strings.

## Anforderungen

### In Scope (v1)

- Eingabe: Zwischenablage-Text, Bilder, PDF (ephemer), inkl. Dateidialog, Drop und iOS „Senden an“/Teilen. Text-PDF über PDFKit-Text; **gescannte Seiten als Bilder** an das Modell (wie Foto), kein OCR-Workaround.
- **Grounding** gegen Quelltext (Few-Shot-Leakage): nur wenn Text vorliegt. Bild-only ohne OCR → kein Token-Grounding; Schutz über Instructions/Few-Shots.
- Store- und Private-iOS: **getrennte** App Groups und URL-Schemes für Share-Handoff (`reisen` vs. `reisen-private`).
- Mehrere Kandidaten: Auswahlliste, Nutzer wählt 0..n, danach Editor nacheinander.
- Einstieg: geöffnete Reise oder Offen-Tab; iOS zusätzlich Share-Sheet.
- Alle `BookingType`-Fälle.
- Kandidat nur mit sicherem `bookingType` und `startAt`.
- Unsichere Felder weglassen. Fehlendes `status` → `.unknown` (kein `.confirmed`).
- Fehlendes `endAt`: `endAt = startAt`, `endAtIsPlaceholder = true`.
- Match store-weit; URL/Code/Fingerprint jeweils 0 → none, 1 → unique, >1 → ambiguous. Fingerprint nur wenn `endAtIsPlaceholder == false`.
- Review Pflicht im `BookingEditor`.
- Create ohne Reise: `BookingEditorDraft.createBooking(..., trip: SDTrip?)` mit `trip == nil` für Offen (kein Dummy-Trip).
- Modell: PCC wenn verfügbar, sonst On-Device, sonst disabled. Lauf-Fehler: Dialog, **kein** zweiten Extract mit der anderen Stufe.
- Privacy-HTML: PCC und Paste-Import.
- Erkennung: Few-Shot-Beispiele DE/EN (Flug inkl. LCC/Screenshot/PNR-unter-Label, Bahn DB/ÖBB/Trainline, Bus/FlixBus/TGV→`train`, Hotel Booking.com/Airbnb, Mietwagen Sixt/Hertz, Event GetYourGuide/Eventbrite, Fähre) in `PasteImportExtractionInstructions`; Typ-Aliase und Ticket-Datenformate im Mapper; Titel-/Operator-**Tokens** (`PasteImportExtractionTypeHint`, kein Substring in „Business“/„Touristenhotel“); AGB-Seiten im PDF-Text weglassen; Material-Zeichenbudget (`PasteImportPromptBudget`, Schnitt an Zeilenenden) vor dem Modellaufruf; `confirmationCode` ohne Labels/Preise/Initialen; fehlendes `startAt` aus Abfahrt/Check-in/Itinerar-Routenzeilen im Quelltext (eine Buchung oder 1:1 bei gleicher Anzahl); komplementäre **Flug-/Boarding**-Fragmente zusammenführen (`PasteImportExtractionCoalescer`, kein Hotel+Flug-Mix); Extrakte ohne Beleg-Tokens im Quelltext verwerfen (`PasteImportSourceGrounding`); Boarding-Pass ohne mehrere Abflüge = ein Eintrag. Unbekanntes Typ-Label bleibt `nil`. Gescannte Bilder nur, wenn die Runtime `Attachment` exportiert — sonst `imageInputUnsupported`, kein Crash.

### Nicht in Scope

- ChatGPT, Perplexity, andere Drittanbieter-LLMs (v2 hinter demselben Resolver).
- Stiller/automatischer Stufenwechsel nach PCC-Fehler.
- F05 Datei an der Buchung.
- Postfach-Scan, Mail-Forward, Inbox-OAuth.
- Speichern ohne Editor.
- Fingerprint bei Platzhalter-`endAt`.
- Mehrdeutigen Match still auf eine Buchung legen (auch nicht über `byURL` last-write).
- `SyncBookingDraftApplier` / Upsert-Loop.
- PCC ohne Bestätigungs-Sheet.

## Architektur

| Schicht | Verantwortung |
|---|---|
| **ReisenDomain** | Quelle, Port `PasteImportExtracting`, Modellstufe, Resolver, Filter, Draft, Match-Tri-State, Merger, Pipeline → Kandidaten. Kein FoundationModels, kein PDFKit, kein UIKit. |
| **ReisenPasteImport** | Availability, Session, ein `@Generable`/`Codable`-Payload (Felder = Extraction), PDFKit-Text + Seiten-Render, Bild-`Attachment`. Output: `[PasteImportExtraction]`. |
| **ReisenAppCore** | Orchestrierung eines Laufs: Availability → Resolver → Extract (ein kind) → Pipeline. Bei Extract-Fehler **kein** Retry mit anderem kind. `PasteImportSessionControlling` für SharedUI-Flow ohne Abhängigkeit auf `ReisenPasteImport`. |
| **ReisenSharedUI** | Aktion (disabled+Begründung), Flow (PCC/Progress/Kandidaten/Fehler), Review-Sheet, Liste, Prefill. Abhängigkeit Domain + Data + AppCore (`PasteImportSessionControlling`). Kein `ReisenPasteImport`. Prefill: Neu aus Draft ohne `createDefault`; Ergänzen = `fromExisting` nach Mapping aus `fillingGaps(DomainMapper.booking(from:), draft)`. |
| **Reisen / ReiseniOS** | Clipboard, Datei, Drop / „Öffnen mit“, Share / „Senden an“, verdrahten Extractor. |
| **ReisenData** | `createBooking(trip: SDTrip?)` (`nil` = Offen); Edit weiter `apply`. |

CI mockt `PasteImportExtracting`. SharedUI mockt keine Modelle.

## Modellwahl

Vor dem Senden sichtbar:

1. PCC, wenn Availability PCC (Gerät **und** managed Entitlement `com.apple.developer.private-cloud-compute`; ohne Entitlement ist PCC nicht verfügbar — kein Lauf gegen Apples Cloud).
2. Sonst On-Device, wenn Availability On-Device.
3. Sonst `unavailable`.

Availability ≠ Lauf-Fehler. Ein fehlgeschlagener PCC-Extract startet **nicht** On-Device, auch nicht nach Rückfrage (v1).

## Datenfluss

```
Quelle → PasteImportSource
  → Resolver(availability) → kind
  → Extractor(kind) → [PasteImportExtraction]
  → Filter → [PasteImportDraft]
  → PasteImportMatching (Indexe) → [PasteImportCandidate]
  → Auswahlliste
  → BookingEditor (Prefill über Merger-SSOT)
  → createBooking(trip:) oder apply
```

## Zuordnung

Index aller Store-Buchungen. Pro Draft:

1. `externalUrl` (nicht leer): Anzahl Buchungen mit derselben URL in `existing` (nicht last-write Map).
2. `confirmationCode`.
3. Datums-Fingerprint nur wenn `!endAtIsPlaceholder`.

Je Schritt: 1 Treffer → unique (fertig); >1 → ambiguous (fertig); 0 → nächster Schritt; nichts → none.

| Match | Badge | Speichern |
|---|---|---|
| unique | **Ergänzen** | Edit; Merger; Trip unverändert |
| none | **Neu** | Create `.manual`; `trip` = aktuelle Reise oder `nil` (Offen) |
| ambiguous | **Neu** + „keine eindeutige Zuordnung“ | wie Neu |

## Fehler

Wie zuvor: unavailable disabled; Modellfehler Dialog ohne Stufenwechsel; leere Quelle Fehler; 0 Kandidaten Leerzustand; Share-Handoff Fehler. Gescannte PDF ohne Text: Seiten als Bilder, nicht `unreadableSource`, sofern Seiten existieren. PDF ohne Seiten: `unreadableSource`.

## UI / HIG

- ⌘V System-Paste. macOS „Buchung einfügen…“ ⌘⇧V in Reise **und** Offen. Dateidialog und **Drop** (Fenster, Dock, „Öffnen mit“) teilen Typen PDF/Bild/Text; ein File pro Drop (erstes gültiges). `LSHandlerRank` Alternate, Rolle Viewer — Reisen wird nicht Default-PDF-App.
- iOS Toolbar plus **eine** Share-Extension, eingebettet in Store-App **und** Private-App. App Group `group.de.reisen.Reisen.pasteimport`. Handoff-URL-Scheme **`reisen://paste-import`** (Info.plist beider iOS-Apps). Consume löscht die Temp-Datei. iPad-Drop, „Öffnen in Reisen“ und **Senden an / Teilen** (Share-Sheet, inkl. `public.file-url` aus der Dateien-App) denselben Datei-Pfad. Datei-URLs aus „Öffnen mit“ landen in `PasteImportExternalFileInbox`, auch bevor Bootstrap `.ready` ist; der Host holt sie nach.
- Badge = L10n-Text (Neu / Ergänzen), nicht nur Farbe; VoiceOver-Label gleich.
- EN-Badge: **Enrich**, nicht Update.
- PCC-Sheet vor dem Senden. Progress + Abbrechen.

## Tests

- Filter, Match (Code unique/ambiguous, URL unique/ambiguous, Fingerprint-Skip bei Platzhalter), Merge, Resolver-Availability, Extract-Fehler ohne Zweitlauf, Mapper (unbekannter Typ nicht `.other`), Prefill ohne Hotel-Defaults, `createBooking(trip: nil)`, L10n, Privacy-Needles.
- RED = fachlicher Assert-Fail auf existierender API (Stubs zuerst), nicht fehlende Typen.
- Kein Live-Modell in CI.

## Privacy

`privacy.html` / `en/privacy.html`: ephemerer Paste-Import; PCC nach Bestätigung; kein Drittanbieter-LLM in v1.

## Offene Punkte (explizit verworfen)

- Drittanbieter-LLM: v2.
- F05.
- Stufenwechsel nach Fehler: nein.
- Belegte Felder überschreiben: nein.
