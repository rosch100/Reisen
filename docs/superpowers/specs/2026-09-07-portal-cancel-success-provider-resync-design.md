# Portal-Storno erkannt → Provider neu synchronisieren

Datum: 2026-09-07
Status: freigegeben (Conformity-Remediation)
Plattformen: macOS (`Reisen`), iOS Private (`ReiseniOS` mit Provider-Hub)

Verwandt: [2026-08-30-in-app-cancellation-sheet-design.md](2026-08-30-in-app-cancellation-sheet-design.md), [booking-portal-open.md](../../dev/booking-portal-open.md)

## Ziel

Wenn der Nutzer im **Cancel-Sheet** einen Portal-Storno **abgeschlossen** hat (oder die Seite bereits „storniert“ zeigt), soll Reisen **automatisch denselben Provider** neu synchronisieren — still im Hintergrund, ohne Sidebar-/Tab-Wechsel. Reisen setzt lokal **kein** `cancelled`; der Sync aktualisiert den Buchungsstatus wie ein manueller Provider-Sync.

## Entscheidungen

| Thema | Wahl |
| --- | --- |
| Erkennung | Nur bei Erfolgs-/bereits-storniert-Heuristik (nicht bei jedem Sheet-Dismiss) |
| Sync-UX | Still: `SyncStore.sync(providerID:…)` mit Hub-WebView; Selection bleibt |
| Architektur | Sticky Flag im Sheet + pure `PortalCancelCompletionDetector` (`ReisenDomain`) + Notification |
| Concurrent Sync | v1: wenn `isSyncing` → skip + Diagnostic; kein Queue |
| Safari-Fallback | kein Auto-Sync (kein Beobachtungskanal) |
| Store-iOS | kein Hub → kein Sheet-Pfad → irrelevant |
| Marker-Quelle | Nur **explizit belegte** Marker; kein Raten, keine URL-Wildcards mit „cancel“ |

## Flow

```text
Cancel-Sheet load(Storno-URL)
        │
        ▼
didFinish → pageText-Probe (innerText, begrenzt) wenn Provider Text-Marker hat
        │
        ▼
Detector.looksCompleted(provider, url, pageText)
        │
        ├── false → Flag unverändert
        └── true  → sticky cancellationLikelyCompleted = true (+ log)
        │
        ▼
Dismiss (Toolbar / Sheet schließen)
        │
        ├── Flag false → nur Owner syncHost, fertig
        └── Flag true  → Owner syncHost, dann post reisenSyncProvider(providerID)
                              │
                              ▼
                     ContentView / iOS Private Root
                              │
                              ├── isSyncing → skip + log
                              └── else → store.sync(…, DiagnosticContext operation: provider_sync_after_cancel)
```

## Detector (SSOT)

Modul: **`ReisenDomain`** (pure, kein WebKit). Eine Datei, z. B. `PortalCancelCompletionDetector.swift`.

```text
looksCompleted(provider: ProviderID, url: URL?, pageText: String?) -> Bool
```

| Regel | Verhalten |
| --- | --- |
| Sticky | Host hält Flag; Detector selbst ist stateless. Einmal `true` in der Sheet-Session bleibt `true` |
| pageText | Pflicht für Provider mit Text-Markern: Sheet liest nach `didFinish` einen begrenzten `document.body.innerText`-Ausschnitt und übergibt ihn. Ohne Text bei Text-only-Providern → `false` |
| False | Provider ohne v1-Marker; leere Inputs; nur Cancel-Einstieg ohne Erfolgsmarker |
| True | Mindestens ein **dokumentierter** Marker trifft |
| Assist | Opodo-Assist darf denselben Text-Marker nutzen (gleiche Literal-SSOT / Aufruf von `looksCompleted`); Confirm-Klick bleibt verboten |

### Marker v1 (geschlossen)

Nur Einträge in dieser Tabelle. Neue Provider/Marker = Spec-Erweiterung + Tests, nicht still im Code.

| Provider | URL-Marker | Text-Marker (case-insensitive) | Negativ (explizit false) |
| --- | --- | --- | --- |
| Opodo | — | Substring `bereits storniert` (bereits in `OpodoCancelAssistScript`) | Trip-Details ohne diesen Text; Cancel-Dialog offen ohne Confirm |
| alle anderen Sync-Provider | — | — | immer `false` in v1 |

**Bekanntes False-Negative-Risiko:** Nach frischem Confirm kann Opodo anderen Bestätigungstext zeigen als `bereits storniert`. Dann kein Auto-Sync, bis Marker belegt und Spec erweitert. Kein Fallback auf „irgendein storniert“.

## Sync-Trigger

- Notification-Name: `reisenSyncProvider`, `object: ProviderID`.
- Definition: **eine** SSOT in `ReisenSharedUI` (macOS `SidebarSelection` migriert darauf bzw. re-exportiert denselben Namen; iOS importiert SharedUI — kein zweites Literal).
- Listener: macOS `ContentView`; iOS Private Composition Root / Sync-fähiger Host (wo `SyncStore` + `providerSessionHub` verfügbar sind).
- `DiagnosticContext.operation`: fest **`provider_sync_after_cancel`** (nicht `provider_sync`).
- Kein Wechsel zu `.providerSync(…)`.
- Reihenfolge: Dismiss → Owner `syncHost` → Notification → Sync (WebView wieder beim Sync-Host).

## Logging

`DiagnosticLogger` + `DiagnosticEvent` (String-`event`, wie übrige Portal-Cancel-Events):

| Event | Wann |
| --- | --- |
| `portal_cancel_completion_detected` | Detector → true (provider; URL host-redacted) |
| `portal_cancel_resync_requested` | Dismiss mit Flag |
| `portal_cancel_resync_skipped_busy` | `isSyncing` |
| `portal_cancel_resync_started` | Sync gestartet |
| Fehler | bestehende Sync-Fehlerpfade |

Keine PII/Klartext-Buchungsnummern.

## Tests

| Schicht | Abdeckung |
| --- | --- |
| `Tests/ReisenDomainTests` | Detector: Opodo + `bereits storniert` → true; Opodo ohne / leerer Text → false; anderer Provider → false; Einstiegs-URLs ohne Marker → false |
| App/Host | optional sticky/Notification ohne WK |
| XCUI | nicht in Scope |

## Nicht-Ziele

- Lokales Setzen von `status = cancelled` ohne Sync
- Auto-Sync bei Safari-`openURL`-Storno
- Sync-Queue bei Busy
- Assist klickt Confirm-Buttons (Opodo „Diese Buchung stornieren“ bleibt verboten)
- Sync-All statt Single-Provider
- Store-iOS
- v1-Marker für Airbnb, Check24, Booking.com, BM, GYG, Traveloka ohne Live-Beleg

## Akzeptanz

1. Sheet schließen ohne Erfolgsmarker → kein Sync.
2. Opodo-Fixture mit `bereits storniert` → sticky Flag → Dismiss → genau ein Single-Provider-Sync, Selection unverändert, `operation == provider_sync_after_cancel`.
3. Während `isSyncing` → kein zweiter Sync, Event `portal_cancel_resync_skipped_busy`.
4. Safari-Fallback → kein Sync.
5. Unit-Tests für Detector; Sheet-Spec verlinkt diesen Nachlauf.

## Sheet-Spec

Nachlauf ist in [2026-08-30-in-app-cancellation-sheet-design.md](2026-08-30-in-app-cancellation-sheet-design.md) ergänzt (stiller Provider-Sync bei erkannter Completion). Weiterhin kein Cancel-API / kein lokales `cancelled` ohne Sync-Ergebnis.
