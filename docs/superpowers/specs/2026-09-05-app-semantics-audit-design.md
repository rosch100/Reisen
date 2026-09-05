# Design: App Semantik-/Logik-Audit (macOS + iOS)

**Datum:** 2026-09-05
**Status:** approved (Cursor-Plan conformity-geschlossen; Spiegel ohne Zweit-Wait)
**Scope:** Wellenweiser Audit + Fix (Priorität 3): Korrektheit, mittlere Lücken, gezielte Optimierungen. Kern zuerst.

## Problem

Stille Fallbacks und asymmetrische Fehlerpfade in Prefs/CloudKit/Zeit/Provider-Sync sowie macOS↔iOS-Drift gefährden Datenqualität und Beobachtbarkeit.

## Ziele

1. Fail-visible Prefs-/Mirror-/CloudKit-Await-Verträge
2. Zeit-Kontrakt ohne `TimeZone.current`-Fallback bei fehlendem Offset
3. Provider-Sync: Partial/Session-Fehler nicht als Success
4. SharedUI/Shell: Persist-Diagnostics und kritische Parität
5. Logging + Tests im selben Diff; Deferrals dokumentiert

## Nicht-Ziele

- Store Wipe-on-Open-Retry umbauen (ohne neue Evidence)
- Vollständiges Zusammenlegen TripDetail mac/iOS
- Airbnb/GYG/Billiger/Traveloka soft-Enrich (außer neuem high Residual)
- DiagnosticLogger Encode-Drop Infra
- Token-Einbettung als Finding

## Policies (SSOT)

Siehe Cursor-/Repo-Plan `2026-09-05-app-semantics-audit`. Kurz:

| Area | Regel |
| --- | --- |
| Prefs | `PrefsImportOutcome`: `applied` / `noRecord` / `failed` — catch nie wie leer |
| Poison-Clear | Delete-Fail → `false`; Snapshot nur nach leerem Mirror verwerfen |
| Mirror | nur Singleton-ID; Dedup wirft; kein `all.first` / `?? []` |
| CloudKit Await | `CloudKitAwaitResult`: `completed` / `timedOut` / `disabled`; Wipe bei Timeout weiter + Diagnostic; Prefs unterscheiden |
| EventKit | fehlender Offset → skip + `.skipped` |
| Flight TZ | zählen/loggen; Persist wirft |
| Deadlines | non-empty ersetzt; empty behält; Epoch 0 ungültig |
| Opodo | throw statt leerer Deadlines |
| Booking Timeline | `timelineFailures > 0` → throw |
| Check24 | Hotel-Tag-Anker; Basket-Drops diagnostizieren |
| Overlap | Map am Screen-Owner nur mit Evidence |

### CloudKit Call-Sites

| Caller | bei `timedOut` |
| --- | --- |
| Prefs `awaitAndApply` | Import versuchen; leer → timedOut-empty; Fehler → `.failed` |
| `AppBootstrap` Wipe | weiter + Diagnostic `.timedOut` |
| TwoDevice Verification | completed vs timedOut unterscheidbar |

## Wellen

W0 Spec → W1 Data/AppCore/Domain → W2 Provider → W3 SharedUI → W4 Shell → W5 Opt/Residual/Verify

## Finding-Ledger

| id | severity | area | status | notes |
| --- | --- | --- | --- | --- |
| W1-prefs-outcome | high | AppCore | fix | PrefsImportOutcome |
| W1-poison-clear | high | AppCore | fix | clear returns failed on delete fail |
| W1-mirror-canonical | high | Data | fix | singleton only; dedupe throws |
| W1-cloudkit-await | high | Data | fix | CloudKitAwaitResult + wipe timedOut log |
| W1-eventkit-tz | high | AppCore | fix | skip missing offset (EventKit + ReminderScheduler) |
| W1-flight-tz | medium | AppCore | fix | skip summary + persist throw |
| W1-deadlines-tests | medium | Domain | fix | replace/retain + epoch gate |
| W2-opodo-throw | high | Opodo | fix | session/enrichment throw |
| W2-booking-partial | high | Booking | fix | timelineFailures > 0 throw |
| W2-check24-tz | medium | Check24 | fix | HotelStayDate today gate |
| W2-opodo-hotel-offset | medium | Opodo | fix | GMT calendarDay; hotelOffsetSeconds bleibt nil bis Enrich |
| W2-booking-deadline-diag | medium | Booking | fix | skip Diagnostic |
| W2-check24-basket | medium | Check24 | fix | drop counter Diagnostic |
| W3-gap-save | medium | SharedUI | fix | PersistAlert + DiagnosticLogger |
| W3-cancel-paste | medium | SharedUI | defer | residual; no high drift this pass |
| W3-gap-xcui | low | SharedUI | defer | PersistFailureAlert reused; kein neuer Identifier |
| W1-cloudkit-verify-await | medium | Data | fix | TwoDeviceVerification meldet timedOut |
| W4-shell-parity | medium | Shell | fix | iOS persist Diagnostics; print→Logger |
| W5-overlap | low | UI | defer | no Main-Thread evidence this pass |
| defer-wipe-open | — | Data | defer | swiftdata-hybrid-cloudkit |
| defer-macos-push | — | Platform | defer | apple-signing |
| defer-airbnb-iana | — | Airbnb | defer | |
| defer-boardtype-unknown | — | Data | defer | |
| defer-diag-encode | — | Diagnostics | defer | |

## DoD / Stop

Pro Welle: Root Cause, Policy, Diagnostics, Semantik-Test, UI-Scripts wenn UI, `/codereview` + `/conformity`. Gesamt: Ledger ohne offene high/medium außer Deferrals.
