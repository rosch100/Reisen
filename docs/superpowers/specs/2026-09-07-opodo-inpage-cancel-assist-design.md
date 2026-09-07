# Opodo: In-Page-Storno (Assist bis Bestätigungsdialog)

Datum: 2026-09-07
Status: freigegeben (Live-Beleg Trip-Detail)
Plattformen: macOS / iOS Private (`REISEN_PROVIDER_SYNC`)

## Ziel

Stornieren öffnet die Opodo-Trip-Detailseite und bringt den Nutzer bis zum **Bestätigungsdialog** — nicht in einen geratenen `funnel=`-Pfad und nicht bis zur finalen Storno-Bestätigung.

## Beleg

- Trip-Detail: `…/travel/secure/…#tripdetails/;td={token}` (gleicher Hash-Raum wie Open).
- Auf der Seite: Eintritt „Buchung abbrechen“ → Dialog mit „Diese Buchung beibehalten“ / „Diese Buchung stornieren“.
- Hash bleibt Trip-Detail; kein nachweisbarer Cold-Deep-Link nötig.
- **„Diese Buchung stornieren“ storniert sofort** — Assist darf diesen Control **nicht** klicken.

## Entscheidung

| Thema | Wahl |
| --- | --- |
| Mode | `inPageOnOpen` |
| `cancellationUrl` | = `externalUrl` (Trip-Detail) |
| Assist (B) | Nach Load: Dialog öffnen („Buchung abbrechen“); Erfolg = Dialog sichtbar |
| Fallback (A) | Assist scheitert → Trip-Detail manuell |
| Nie | Klick auf „Diese Buchung stornieren“ |
| `funnel=cancellationHSA` | nicht als Template (ohne Cold-Beleg) |

## Akzeptanz

1. Catalog Hotel/Flug: `cancellationUrl == externalUrl`.
2. Policy Opodo = `inPageOnOpen`.
3. Assist öffnet Dialog oder belässt Detail; kein Auto-Confirm.
4. Diagnostics ohne Token/PII.
