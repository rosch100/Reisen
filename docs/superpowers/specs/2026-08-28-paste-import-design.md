# Paste-Import (F06) — Design

Datum: 2026-08-28  
Status: Entwurf (Brainstorming, User-Review ausstehend)  
Backlog: [feature-backlog.md](../../dev/feature-backlog.md) F06  
Muster: manueller `BookingEditor` + `ProviderBookingDraft`; Match über `SyncBookingMatchLookup`

## Ziel

Der Nutzer fügt Bestätigungsmaterial (Text, Bild, PDF) ein. Die App extrahiert Buchungskandidaten on-device oder über Apple Private Cloud Compute, der Nutzer wählt und prüft jede Buchung im bestehenden `BookingEditor`, erst dann wird gespeichert. Das ergänzt Provider-Sync für Bahn, Restaurant und unbekannte OTAs — ohne Inbox-OAuth.

## Begriffe (SSOT)

| Begriff | Bedeutung |
|---|---|
| **Quelle** (`PasteImportSource`) | Ephemeres Material: Text, Bild-Bytes oder PDF-Bytes. Wird nicht als Anhang persistiert (F05 bleibt getrennt). |
| **Resolver** (`PasteImportModelResolver`) | Wählt genau eine Modellstufe und meldet sie der UI *vor* dem Lauf. |
| **Modellstufe** | `privateCloudCompute` \| `onDevice` \| `unavailable`. Kein Drittanbieter in v1. |
| **Kandidat** (`PasteImportCandidate`) | Gefilterter Domain-Draft plus Match-Ergebnis (Neu vs. Ergänzen). |
| **Neu** | Kein eindeutiger Sync-Treffer → `ProviderID.manual`, Editor Create. |
| **Ergänzen** | Eindeutiger Treffer via `SyncBookingMatchLookup` → bestehender Provider bleibt, Editor Edit, nur Lücken füllen. |
| **Lücke** | Optionales Buchungsfeld, das in der bestehenden Entity leer/`nil` ist. |

## Anforderungen

### In Scope (v1)

- Eingabe: Zwischenablage-Text, Bilder, PDF (ephemer).
- Mehrere Kandidaten: Auswahlliste, Nutzer wählt 0..n, danach Editor nacheinander.
- Einstieg: geöffnete Reise oder Offen-Tab (unzugeordnet); iOS zusätzlich Share-Sheet.
- Alle `BookingType`-Fälle (`flight`, `hotel`, `ferry`, `train`, `activity`, `carRental`, `other`).
- Kandidat nur mit sicherem `bookingType` und `startAt`.
- Unsichere Felder: weglassen, nicht raten.
- Fehlendes `endAt`: `endAt = startAt` und Flag `endAtIsPlaceholder = true`.
- Match gegen bestehende Buchungen mit bestehendem `SyncBookingMatchLookup`.
- Review Pflicht im bestehenden `BookingEditor`.
- Modell: PCC wenn verfügbar, sonst On-Device, sonst disabled mit Begründung.
- Datenschutzerklärung: PCC und Paste-Import beschreiben.

### Nicht in Scope

- ChatGPT, Perplexity oder andere Drittanbieter-LLMs (Port/`LanguageModel` so belassen, dass v2 andocken kann).
- Stiller oder automatischer Stufenwechsel (PCC-Fehler → nicht On-Device).
- F05: PDF/Bild an der Buchung speichern.
- Postfach-Scan, Mail-Forward, Inbox-OAuth.
- Automatisches Speichern ohne Editor.
- Fingerprint-Match, wenn `endAt` nur Platzhalter ist.
- Mehrdeutigen Match still auf eine Buchung legen.
- `SyncBookingDraftApplier` / Upsert-Schleife für Paste (die verlangt `externalUrl` und überschreibt Provider-Felder).
- Private Cloud Compute ohne vorherige Bestätigung.

## Architektur

Port in Domain, Adapter mit Foundation Models, UI nur Review und Einstieg.

| Schicht | Verantwortung |
|---|---|
| **ReisenDomain** | `PasteImportSource`, `PasteImportExtracting` (Port), `PasteImportModelKind`, Resolver-Ergebnis, Filter Typ+`startAt`, `endAt`-Platzhalter, Match-Aufruf auf `SyncBookingMatchLookup`, Merge „nur Lücken“. Kein FoundationModels, kein PDFKit, kein UIKit. |
| **ReisenPasteImport** (neues Target) | `SystemLanguageModel` / `PrivateCloudComputeLanguageModel`, `@Generable`-DTO, Mapping → `ProviderBookingDraft`, PDFKit (Text; gescannte Seiten als Bilder), Bild-Attachments soweit das SDK das hergibt. Verfügbarkeit explizit. |
| **ReisenSharedUI** | Disabled-Aktion + Begründung, Modell-Caption/PCC-Bestätigung, Auswahlliste, Prefill `BookingEditorDraft`. |
| **Reisen / ReiseniOS** | Menü/Toolbar, Datei/Foto, Clipboard. iOS Share-Extension reicht Payload ephemer an die App. |
| **ReisenData** | Unverändert: Speichern nur über `BookingEditorDraft.createBooking` / `apply`. |

Domain-Tests mocken den Port. CI ruft kein Apple-Modell.

## Modellwahl

Eine Stufe pro Lauf, in der UI sichtbar bevor Material gesendet wird:

1. `PrivateCloudComputeLanguageModel`, wenn verfügbar.
2. Sonst `SystemLanguageModel` (On-Device), wenn verfügbar.
3. Sonst `unavailable`: Aktion sichtbar, disabled, Begründung (Gerät / Apple Intelligence).

Schlägt die gewählte Stufe fehl (Netz, Quota, Session): Fehlerdialog, **kein** Wechsel auf die andere Stufe. Timeout und Abbruch: Fehler, keine Teil-Kandidaten aus abgeschnittenem JSON.

v2-Erweiterung: dritter `LanguageModel`-Provider (ChatGPT/Perplexity o. ä.) nur hinter demselben Resolver, mit eigener Kind-Variante — nicht in v1.

## Datenfluss

```
Quelle (Clipboard | Datei | iOS-Share)
  → PasteImportSource (ephemer)
  → Resolver (PCC | onDevice | unavailable)
  → Adapter: PDF/Bild aufbereiten, @Generable-Liste
  → Domain-Filter (Typ + startAt; unsichere Felder leer)
  → Match (SyncBookingMatchLookup)
  → Auswahlliste (Neu / Ergänzen)
  → nacheinander BookingEditor
  → createBooking (.manual) oder apply (bestehende Entity)
```

Keine Anreicherung aus dem Sync-Store außer dem Match. Share-Extension schreibt nichts in SwiftData.

## Zuordnung

Nach dem Filter, für jeden Kandidaten, Index **aller** Buchungen im Store (wie Sync, nicht nur die aktuelle Reise):

1. `externalUrl`, wenn der Draft eine hat.
2. Eindeutiger `confirmationCode`.
3. Eindeutiger Datums-Fingerprint **nur wenn** `endAtIsPlaceholder == false`.

| Match | Liste | Speichern |
|---|---|---|
| genau einer | Badge **Ergänzen** | Editor Edit; Merge nur Lücken; **Trip der bestehenden Buchung bleibt** (Paste verschiebt nicht) |
| keiner | Badge **Neu** | Create, `ProviderID.manual`; Trip = aktuelle Reise oder `trip == nil` (Offen) |
| mehrere | Badge **Neu** plus Hinweis „keine eindeutige Zuordnung“ | wie Neu |

**Merge (nicht `SyncBookingDraftApplier`):** nur leere Felder der bestehenden Buchung aus dem Paste füllen. `provider`, `externalUrl`, `lastSyncedAt`, `trip` unverändert. Belegte Felder ändert nur der Nutzer im Editor. Sync-Overwrite-Hinweis bleibt für Nicht-`.manual`.

Create-from-Paste **nicht** über `BookingEditorDraft.createDefault` (dort stehen Hotel-Minuten-Defaults). Mapper: unsichere/fehlende optionale Felder leer lassen.

## Fehler

| Situation | Verhalten |
|---|---|
| `unavailable` | Disabled + Begründung |
| Modellfehler | Dialog; kein Stufenwechsel |
| Leere/unlesbare Quelle | Fehler, kein leerer Extraktionslauf |
| 0 gültige Kandidaten | Leerzustand mit Erklärung, kein Dummy |
| Unsicheres Feld | Feld weglassen, Rest behalten |
| Mehrdeutiger Match | Neu + Hinweis |
| Editor Abbrechen | nur dieser Kandidat weg; Queue bleibt |
| Share-Handoff fehlgeschlagen | Fehler; keine Datei im Store |
| PCC | Bestätigungs-Sheet bevor Material die App verlässt |

## UI / HIG

- ⌘V bleibt System-Paste in Textfeldern.
- macOS: Menü neben „Buchung hinzufügen“: „Buchung einfügen…“ (⌘⇧V), aktiv in Reise oder Offen.
- iOS: gleicher Eintrag in Toolbar/Menü, Datei/Foto; Share-Extension für Text, Bild, PDF. Die Extension schreibt den Payload in den App-Group-Temp und löscht ihn nach dem Consume; kein SwiftData in der Extension.
- Vor dem Lauf: Caption On-Device vs. PCC. PCC: Bestätigungs-Sheet. On-Device: nur Caption.
- Lauf: `ProgressView`, Abbrechen → Fehlerzustand.
- Liste: `BookingType`-Symbol, Titel oder Code, Datum, Badge Neu/Ergänzen; Mehrfachauswahl, Standard alle an.
- Editor-Queue: bestehender `BookingEditor` (Create vs. Edit).
- a11y: VoiceOver für Aktion, Modell, Badge; Dynamic Type; Badge nicht nur Farbe.

## Tests

Verhalten, nicht Live-Modell.

- Filter: Typ+`startAt` Pflicht; Platzhalter-`endAt`; unsichere Felder leer.
- Match: eindeutiger Code trifft; Fingerprint nur ohne Platzhalter-`endAt`; Mehrdeutigkeit → kein Match.
- Merge: nur Lücken; Provider/URL/`lastSyncedAt`/`trip` unverändert.
- Resolver: PCC → PCC; sonst On-Device; sonst unavailable; kein stiller Wechsel.
- Mapper: `@Generable`-Fixture → Domain-Draft; Neu-Anlagen `provider == .manual`.
- SharedUI: Disabled+Begründung; Liste Neu vs. Ergänzen; Editor-Prefill.
- L10n de/en.
- Legal: Privacy-HTML erwähnt Paste-Import und PCC (bestehende Legal-Content-Tests erweitern).

CI: Port mocken. Keine abgeschwächten Assertions. Kein Dummy-Kandidat gegen leere Liste.

## Privacy

`docs/legal/privacy.html` und `en/privacy.html`: Paste-Import (Text/Bild/PDF nur ephemer zur Extraktion) und Private Cloud Compute (Buchungsinhalt verlässt das Gerät, Apples PCC-Garantie, Opt-in per Bestätigungs-Sheet). Kein Widerspruch zwischen Text und Verhalten.

## Offene Punkte (explizit verworfen, nicht TBD)

- Drittanbieter-LLM: v2, nicht v1.
- Datei an der Buchung: F05.
- Automatischer Stufenwechsel nach PCC-Fehler: nein.
- Belegte Felder im Editor mit Paste überschreiben: nein (nur Lücken).
