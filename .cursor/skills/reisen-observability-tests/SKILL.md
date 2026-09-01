---
name: reisen-observability-tests
description: >-
  Ensures Reisen product changes ship DiagnosticLogger events and tests
  (Swift Testing plus macOS XCUI). Use when implementing features or bugfixes,
  touching sync/navigation/persistence/UI identifiers, or when logging/tests
  are missing from a behavioral diff.
---

# Reisen: Observability + Tests

Begleit-Skill zur Rule `reisen-logging-and-tests`. **Kein** Ersatz für `/feature-dev` oder `/bugfix` — dort in Inner/DoD einbinden. Architekturgrenzen: Rule `reisen-architecture` / `docs/ARCHITECTURE.md`.

## Wann

- Neues oder geändertes Laufzeitverhalten
- User-sichtbare UI (macOS / SharedUI)
- Sync, Provider, Navigation, Persistenz, Side-Effects, Fehlerpfade

## Checkliste (kopieren)

```
Observability/Tests:
- [ ] DiagnosticEvent an Start/Erfolg/Fehler/Timeout (oder begründet entbehrlich)
- [ ] Keine Secrets/PII im Klartext; URL-Rohwerte nur über Diagnostics-Redaction
- [ ] Unit-/Swift-Testing-Assert trifft Spec
- [ ] UI: UITestingIdentifiers + MacUI/XCUI (wenn Oberfläche betroffen)
- [ ] bash ./Scripts/ci-test.sh
- [ ] UI-Diff: bash ./Scripts/macos-ui-test.sh
```

## Logging-SSOT

| Stück | Ort |
| --- | --- |
| Events | `Sources/ReisenDiagnostics/DiagnosticEvent.swift` |
| Context | `DiagnosticContext` (`runID`, `providerID`, `operation`); `@TaskLocal` wo Sync-Run |
| Sink | `DiagnosticLogger.shared.record(_:)` / `flush()` |
| Datei | `SyncLog` → Application Support `sync-log.txt` |

### Muster

```swift
await DiagnosticLogger.shared.record(
    DiagnosticEvent(
        context: diagnosticContext,
        component: "ComponentName",
        phase: "phase",
        event: "event_name",
        result: .failed, // started | succeeded | failed | timedOut | cancelled | skipped
        reason: "stable_machine_reason",
        visibility: .publicDiagnostic // oder .localDebugOnly
    )
)
```

- `component` / `phase` / `event` / `reason`: stabile Maschinenstrings (keine L10n).
- `visibility: .localDebugOnly` nur für Debug-Rauschen; Release schreibt das nicht.
- Nach kritischen Sync-/Probe-Blöcken `flush()` wo bestehender Code das schon tut.
- Kein paralleles Diagnose-Format erfinden.

Referenz-Beispiele: `NavigationSettlePoll`, `ProviderLoginAssistance`, Tests in `Tests/ReisenAppCoreTests/DiagnosticLoggerTests.swift`.

## Unit-/Domain-Tests

- Swift Testing (`@Test`) in `Tests/<Modul>Tests/`.
- Fachliche Asserts (Spec), keine Tautologien.
- Runner: `bash ./Scripts/ci-test.sh` (SSOT zu CI).

## UI-Tests (macOS)

| Stück | Ort |
| --- | --- |
| Identifier-SSOT | `Sources/ReisenSharedUI/UITestingIdentifiers.swift` |
| Page Object | `Tests/ReisenMacUITests/MacUI.swift` |
| Smokes | `Tests/ReisenMacUITests/MacUISmokeTests.swift` |
| Script | `bash ./Scripts/macos-ui-test.sh` |
| Advisory Tour | `bash ./Scripts/macos-ui-review.sh` + Skill `ui-surface-review` |

Pflichten bei UI-Diff:

1. Neues Control → Identifier in `UITestingIdentifiers` + `.accessibilityIdentifier(...)` in der View.
2. Neuer/erweiterter Smoke in `MacUISmokeTests` (oder Page-Object-Helper), wenn Journey user-sichtbar ist.
3. Queries nur über Identifier, nie L10n-Titel.
4. Launch: `MacUI.launchPopulated()` / `launchEmpty()`; CloudKit aus (`REISEN_CLOUDKIT=0`).

iOS: kein Simulator-XCUI-Target als Gate — Identifier trotzdem SharedUI-SSOT; iOS-Lauf über `Scripts/ios-test.sh`.

## Ausnahmen (eng)

- Reine Docs/Rules/Workflow-YAML ohne Produktcode
- Rein mechanisches Rename ohne Semantikänderung (bestehende Tests müssen grün bleiben)
- Pure Berechnung ohne I/O: Unit-Test Pflicht, DiagnosticLogger optional

Ausnahme im PR/Chat **kurz begründen**, nicht still weglassen.

## DoD

Arbeit ist nicht fertig, solange Checkliste offen ist oder Scripts für den Diff-Scope rot/unausgeführt sind.
