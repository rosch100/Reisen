# Provider Session Hub & Login-Ampel — Design

Datum: 2026-07-17  
Status: freigegeben (Brainstorming) → Umsetzung

## Ziel

In der Provider-Sidebar eine Ampel (grün/rot) zeigen, die den Login-Status anzeigt. Aktivierte Provider halten parallele WebView-Sessions (wie Browser-Tabs), damit der Status für alle aktiven Provider gleichzeitig aktuell ist.

## Entscheidungen

| Thema | Wahl |
|-------|------|
| Ampel-Farben | A: grün = angemeldet, rot = nicht angemeldet |
| Parallelisierung | B: nur aktivierte Provider (Checkbox an) |
| Deaktiviert | C: Ampel ausgegraut |
| Architektur | 1: zentraler `ProviderSessionHub` |

## Architektur

### `ProviderSessionHub` (`@Observable`, Environment)

Pro aktiviertem `ProviderID` ein Slot:

- `WKWebView` (lebend, ggf. unsichtbar)
- `ProviderSessionStatus` (`needsLogin` / `sessionReady`)
- Login-URL aus Registry

Lifecycle:

- Checkbox an → Slot anlegen, Login-URL laden, Status via bestehende `AuthPageURLHeuristic` pflegen
- Checkbox aus → Slot freigeben; Ampel grau
- Provider-Wechsel in der Sidebar zerstört keine anderen Slots

### UI

Sidebar-Zeile: Logo → Name → Spacer → **Ampel** → Checkbox → Sync-Spinner

- aktiv + `sessionReady` → grün
- aktiv + `needsLogin` → rot
- deaktiviert → grau

Detail: zeigt nur den selektierten Slot sichtbar/interaktiv; andere bleiben im Tree (Session/Cookies erhalten).

`SyncView` bezieht WebView/Status aus dem Hub (kein lokales Session-`@State` mehr für WebView).

### Fehler

- Fehlende Login-URL / Provider nicht in Registry: kein WebView, Status rot, bestehende Detail-Fehlermeldung
- Keine stillen Fallbacks

## Tests

- Ampel-Mapping (ready→grün, needsLogin→rot, disabled→grau)
- Hub: Enable legt Slot an, Disable entfernt Slot
- URL-Heuristik unverändert wiederverwenden

## Explizit nicht in diesem Design

- Gelb-/Zwischenzustand
- WebViews für deaktivierte Provider
- Persistenz des Ampel-Status unabhängig von der Live-Session
