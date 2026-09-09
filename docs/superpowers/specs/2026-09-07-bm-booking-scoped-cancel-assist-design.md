# billiger-mietwagen: Buchungs-Storno (Assist B + Fallback A)

Datum: 2026-09-07
Status: freigegeben
Plattformen: macOS (`Reisen`) und iOS Private (`REISEN_PROVIDER_SYNC`)

## Ziel

Stornieren öffnet den **buchungsspezifischen** BM-Cancel-Flow (Formular mit Buchungsdaten), nicht den Gast-Lookup auf `/reservation/cancellation`.

## Beleg

- Cold `/reservation/cancellation` → „Welche Buchung möchtest du stornieren?“ (Nummer + Geburtsdatum).
- Von `/reservation/account/bookings/{id}` → Klick „Buchung stornieren“ → SPA-Nav mit `history.state.usr.pushedFrom` + In-Memory-Kontext → „Prüfe bitte, ob dies die Buchung ist…“.
- History-State allein ohne Detail-Load reicht nicht.

## Entscheidung

| Thema | Wahl |
| --- | --- |
| Mode | `inPageOnOpen` |
| `cancellationUrl` | = `externalUrl` (Buchungsdetail) |
| Primär (B) | Nach Sheet-Load einmal Assist: Portal-Button „Buchung stornieren“ auslösen |
| Fallback (A) | Assist scheitert → Nutzer bleibt auf Buchungsseite |
| Scope Assist | nur `ProviderID.billigerMietwagen` |
| Generische Cancel-URL | nicht mehr als Storno-Ziel persistieren |
| Logging | `DiagnosticLogger` Assist started/succeeded/failed/skipped |
| Cancel-API | nein |

## Nicht-Ziele

- Assist für andere Provider
- Safari bei In-Page (unverändert)
- Store-iOS ohne Hub (kein Storno-Control)
- Mehrfach-Retry / DOM-Klick-Schleifen

## Akzeptanz

1. Catalog: `cancellationUrl == externalUrl` (Booking-Page).
2. Policy BM = `inPageOnOpen`; Session erforderlich.
3. Sheet + Session: möglichst Cancel-Formular der Buchung; sonst Buchungsdetail mit manuellem Storno.
4. Assist-Events ohne PII/Buchungs-IDs im Klartext.
