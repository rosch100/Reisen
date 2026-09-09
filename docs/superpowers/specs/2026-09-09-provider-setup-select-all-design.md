# Design: „Alle“ im Dialog Buchungsportale wählen

**Datum:** 2026-09-09
**Status:** approved (feature-dev full_auto; Gapfill zu First-Launch-Setup; Conformity 2026-09-09)
**Basis:** `docs/superpowers/specs/2026-09-04-provider-first-launch-setup-design.md`
**Scope:** SharedUI-Sheet `ProviderFirstLaunchSetupSheet` — **macOS und iOS** über denselben View (Hosts: `ContentView` / `RootTabView`). Keine Änderung der Persistenz-/Host-Verträge.

## Problem

Im Erststart-Dialog „Buchungsportale wählen“ müssen Nutzer jedes Portal einzeln toggeln. Bei vielen Sync-Providern fehlt eine schnelle Massenaktion.

## Ziel

Ein Button **Alle**, der die lokale Sheet-Auswahl **ein- oder ausschaltet**:

- Nicht alle ausgewählt (leer oder partiell) → alle Sync-Portale auswählen.
- Alle bereits ausgewählt → Auswahl leeren.

Continue / Ohne Buchungsportale / Persistenz bleiben unverändert.

## Nicht-Ziele

- Settings-Section „Buchungsportale“ (eigene Toggles, kein Auswahldialog).
- Neues Logging für die lokale Auswahl (wie Einzel-Toggles; Persistenz-Events bleiben Host-seitig).
- Änderung von `ProviderFirstLaunchSetup.applySelection` / Gate / Hide.
- Eigenes iOS-XCUI-Target (existiert nicht) — Plattformbeleg über SharedUI + `ios-test.sh`.

## Entschiedene Alternativen

| Ansatz | Beschreibung | Urteil |
| --- | --- | --- |
| **A — Ein Toggle-Button „Alle“ (gewählt)** | Ein Control; Semantik select-all / clear-all | Entspricht der Anforderung; wenig Chrome |
| B — Zwei Buttons „Alle ein“ / „Alle aus“ | Explizit, mehr Platz | YAGNI |
| C — Master-Toggle als erste Zeile | SwiftUI-Toggle statt Button | Weniger klar als Label „Alle“ |

## UI-Vertrag

- Placement: oben in der Provider-`Form` (vor den einzelnen Toggles).
- Label: L10n `setup.providers.all` — DE **Alle**, EN **All**.
- Accessibility-Identifier: `setup.providers.all` (`UITestingIdentifiers.providerSetupSelectAll`).
- Accessibility-Hint: zustandsabhängig —
  - nicht alle gewählt → `setup.providers.all_select_help`
  - alle gewählt → `setup.providers.all_deselect_help`
- Selection bleibt `@State` im Sheet bis Continue/Later.
- Plattformen: keine `#if os`-Verzweigung für den Button; Sheet-Chrome bleibt wie Basis-Spec (macOS fitted / iOS detents).

## Domain-/Hilfsvertrag

Reine Funktionen in `ProviderSetupSelection` (SharedUI, kein I/O):

```text
areAllSelected(current:allIDs:) -> Bool
  true iff allIDs nicht leer und jedes Element in current

toggleAll(current:allIDs:) -> Set<ProviderID>
  wenn areAllSelected → []
  sonst → Set(allIDs)
```

Leere `allIDs` → `areAllSelected=false`, `toggleAll` → leeres Set.

## Schnittstellen (`live_app`)

| id | kind | supply | evidence |
| --- | --- | --- | --- |
| setup-select-all-button | entry | Button im SharedUI-Setup-Sheet (macOS+iOS Hosts) → nur lokale `selection` | Unit `ProviderSetupSelectionTests` + macOS Empty-Smoke Existence |
| setup-select-all-id | neighbor | `UITestingIdentifiers` / L10n-Keys | `UITestingIdentifiersTests` |
| ios-sharedui-compile | neighbor | iOS Host baut SharedUI-Sheet mit Button | iOS Simulator `xcodebuild … build` (Scheme `ReiseniOS`) Exit 0 |

Kein neues `capability` / `adapter` / `corpus`. `open_gaps`: iOS-XCUI-Target fehlt weiterhin (wie Basis-Spec).

## Tests

1. Helper: partial → all; all → empty; empty → all; `areAllSelected`.
2. Identifier-String-Assert.
3. macOS Empty-Smoke: Sheet sichtbar → `setup.providers.all` existiert (Reach-only).
4. iOS: Simulator-Build Scheme `ReiseniOS` (SharedUI inkl. Alle-Button). `ios-test.sh` bleibt CI-SSOT; fehlendes iOS-XCUI-Target und Runner-Bootstrap-Flakes sind `open_gaps`, kein Feature-Blocker bei grünem Build.

## Logging

Keine neuen `DiagnosticEvent`s für den Alle-Button (lokale UI-Auswahl ohne Persistenz).
