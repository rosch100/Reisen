# Provider Setup „Alle“ Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Im Dialog „Buchungsportale wählen“ einen Button „Alle“ einbauen, der die lokale Portal-Auswahl komplett ein- bzw. ausschaltet (macOS + iOS via SharedUI).

**Architecture:** Reine Selection-Hilfsfunktion + Button in `ProviderFirstLaunchSetupSheet`; L10n/Identifier nach bestehendem `setup.providers.*`-Muster. Persistenz erst bei Continue/Later wie bisher.

**Tech Stack:** SwiftUI SharedUI, ReisenDomain L10n, Swift Testing, macOS XCUI (`ReisenMacUITests`), iOS via `ios-test.sh`.

## Global Constraints

- Nur Setup-Sheet; Settings-Portale unverändert.
- Keine stillen Fallbacks; leere Provider-Liste → leere Selection.
- Logging + Tests laut Repo-Rule nur wo Laufzeitpfad/Persistenz betroffen — hier Unit + Identifier + Smoke Existence + iOS-Build/Test.
- UI-Diff: Agents `bash ./Scripts/macos-ui-test-remote.sh`.
- iOS: `bash ./Scripts/ios-test.sh`.

---

## Task 1: Selection-Helper + Unit-Tests (TDD)

**Files:**
- Create: `Sources/ReisenSharedUI/ProviderSetupSelection.swift`
- Create: `Tests/ReisenSharedUITests/ProviderSetupSelectionTests.swift`

- [x] Write failing tests: empty→all, partial→all, all→empty, empty-allIDs→empty, areAllSelected
- [x] Implement `ProviderSetupSelection.areAllSelected` / `toggleAll`
- [x] Run targeted tests green

## Task 2: Sheet-UI + L10n + Identifier (macOS + iOS SharedUI)

**Files:**
- Modify: `Sources/ReisenSharedUI/ProviderFirstLaunchSetupSheet.swift`
- Modify: `Sources/ReisenDomain/Localization/L10nKey.swift`
- Modify: `Sources/ReisenDomain/Resources/Localizable.xcstrings`
- Modify: `Sources/ReisenSharedUI/UITestingIdentifiers.swift`
- Modify: `Tests/ReisenSharedUITests/UITestingIdentifiersTests.swift`
- Modify: `Tests/ReisenMacUITests/MacUISmokeTests.swift` (Existence Reach-only)
- Modify: Basis-Spec First-Launch (SSOT Alle-Button)

- [x] Add L10n `setup.providers.all` + zustandsabhängige Help-Keys
- [x] Add `providerSetupSelectAll` identifier
- [x] Wire Button above provider toggles; call Helper; zustandsabhängiger Hint
- [x] Identifier + Empty-Smoke Existence asserts
- [x] `bash ./Scripts/ci-test.sh` + remote UI Diff + `bash ./Scripts/ios-test.sh`
