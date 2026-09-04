# Provider First-Launch Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Geführte HIG-konforme Erststart-Auswahl der Sync-Provider (Sheet) auf macOS und iOS, aufbauend auf Opt-in-Defaults aus PR #138.

**Architecture:** Domain-Gate/`applySelection` in `ReisenDomain`; Sheet in `ReisenSharedUI`; Host in macOS `ContentView` + iOS `RootTabView`; UITesting-Seeds in `ReisenAppCore`. Keine Parallel-Settings-Semantik — weiterhin `AppSettingsKeys.providerEnabledKey`.

**Tech Stack:** SwiftUI, Swift Testing, XCUI (macOS remote), `DiagnosticLogger`, `AppSettingsDefaults`.

## Global Constraints

- Domain ohne SwiftUI/WebKit; Settings-Keys nur über `AppSettingsKeys`.
- Keine stillen Fallbacks; Continue disabled bei 0 Auswahl.
- UITesting: Populated unterdrückt Sheet; Empty zeigt Sheet.
- Logging + Tests im selben Diff (`reisen-observability-tests`).
- Identifier-SSOT: `UITestingIdentifiers`; Agents-UI: `bash ./Scripts/macos-ui-test-remote.sh`.
- iOS-XCUI fehlt → Compile via `ios-test.sh`; Identifier trotzdem setzen.
- Optik: Systemfarben/Typo; kein Lila-Gradient/Glow/Pill-Cluster.

---

### Task 1: Domain Gate + applySelection (TDD)

**Files:**
- Create: `Sources/ReisenDomain/Settings/ProviderFirstLaunchSetup.swift`
- Modify: `Sources/ReisenDomain/Settings/AppSettings.swift` (Keys)
- Test: `Tests/ReisenDomainTests/ProviderFirstLaunchSetupTests.swift`

**Interfaces:**
- Consumes: `ProviderID.syncProviderIDs`, `AppSettingsKeys.providerEnabledKey`, `AppSettingsDefaults`
- Produces:
  - `AppSettingsKeys.providerSetupCompleted` / `providerSetupDeferred`
  - `ProviderFirstLaunchSetup.shouldPresent(defaults:) -> Bool`
  - `markCompleted` / `markDeferred`
  - `applySelection(enabledIDs:syncProviderIDs:defaults:)` (SSOT-Signatur; Spec-identisch)
  - `bootstrapCompletedIfExistingProviders(defaults:syncProviderIDs:) -> Bool` (setzt completed wenn enabled-Key existiert)

- [x] **Step 1: Write failing tests** for shouldPresent matrix, applySelection explicit true/false, bootstrap heuristic

- [x] **Step 2: Run** `swift test --filter ProviderFirstLaunchSetupTests` (oder Repo-Filter laut Package)
  Expected: FAIL (type missing)

- [x] **Step 3: Implement** Domain unit + Keys

- [x] **Step 4: Run tests** Expected: PASS

- [x] **Step 5: Commit** `feat(domain): ProviderFirstLaunchSetup gate and applySelection`

---

### Task 2: UITesting seed + Bootstrap hook (TDD)

**Files:**
- Modify: `Sources/ReisenAppCore/UITestingLaunch.swift`
- Modify: `Sources/ReisenAppCore/AppBootstrap.swift` (nach ProviderEnabledDefaultsMigration: bootstrapCompletedIfExisting + seed)
- Test: `Tests/ReisenAppCoreTests/UITestingLaunchTests.swift` (+ ggf. neuer Bootstrap-Test)

**Interfaces:**
- Consumes: `ProviderFirstLaunchSetup`, `UITestingMode`
- Produces: `UITestingLaunch.seedProviderSetupIfNeeded(mode:defaults:)` — populated → `markCompleted`

- [x] **Step 1: Failing tests** populated seeds completed; empty does not; existing provider key → bootstrap marks completed

- [x] **Step 2: Run filter** Expected: FAIL

- [x] **Step 3: Implement seeds + bootstrap call order** (Migration → bootstrap setup → seed enablement/setup)

- [x] **Step 4: PASS + Commit** `feat(appcore): seed and bootstrap provider setup flags`

---

### Task 3: SharedUI Sheet + L10n + Identifiers (TDD light)

**Files:**
- Create: `Sources/ReisenSharedUI/ProviderFirstLaunchSetupSheet.swift`
- Modify: `Sources/ReisenSharedUI/UITestingIdentifiers.swift`
- Modify: `Sources/ReisenDomain/Localization/L10nKey.swift`
- Modify: `Sources/ReisenDomain/Resources/Localizable.xcstrings`
- Test: Domain/UITesting identifier string stability test optional; Preview nicht nötig

**Interfaces:**
- Consumes: `ProviderRegistry` env / sync IDs; bindings for selection Set; callbacks `onContinue` / `onLater`
- Produces: Sheet UI with identifiers from Spec; Weiter disabled wenn selection empty

- [x] **Step 1: Add Identifiers + L10n keys (DE/EN)**

- [x] **Step 2: Implement Sheet** (Header Symbol + Title + Subtitle; Toggle-Liste; Weiter prominent / Später)

- [x] **Step 3: Unit-smokebar** compile via `bash ./Scripts/ci-build.sh --arch arm64` or package filter SharedUI if available

- [x] **Step 4: Commit** `feat(ui): ProviderFirstLaunchSetupSheet HIG layout`

---

### Task 4: macOS Host + Empty Reopen + Logging

**Files:**
- Modify: `Sources/Reisen/App/ContentView.swift`
- Test: Domain already; XCUI in Task 5

**Interfaces:**
- Consumes: `ProviderFirstLaunchSetup.shouldPresent`, Sheet, `applySelection`, DiagnosticLogger
- Produces: sheet presentation state; Reopen CTA on empty state; Continue → notify + select first enabled

- [x] **Step 1: Wire `@State showProviderSetup`**; present when shouldPresent after probe/bootstrap ready (avoid flash: onAppear + settings epoch)

- [x] **Step 2: Continue/Later handlers + DiagnosticEvents** (`provider_setup_presented` / `_completed` / `_deferred`)

- [x] **Step 3: Empty-State Reopen button** when `!completed && enabled.isEmpty`

- [x] **Step 4: Commit** `feat(macos): host provider setup sheet and reopen CTA`

---

### Task 5: iOS Host + Reopen + macOS XCUI Smoke

**Files:**
- Modify: `Apps/ReiseniOS/Shared/RootTabView.swift` (Sheet-Host)
- Modify: `Apps/ReiseniOS/ProviderSync/SyncTab.swift` (`emptyProviders` Reopen-CTA → Binding/Callback Sheet)
- Modify: `Tests/ReisenMacUITests/MacUI.swift`
- Modify: `Tests/ReisenMacUITests/MacUISmokeTests.swift`
- Modify: `Tests/ReisenMacUITests/MacUIReviewTourTests.swift` (Empty: dismiss then emptyState)

**Interfaces:**
- live_app Empty-Vertrag laut Spec:
  1. `waitForWindow` akzeptiert `setup.providers.sheet`
  2. Neuer Smoke: Existence-only Sheet (kein Continue/Later)
  3. `dismissProviderSetupIfPresent()` → Later-Tap vor `emptyState` / `createTripViaEmptyCTA` / ReviewTour Empty
  4. Populated: sheet identifier count == 0
- Continue-XCUI out of scope (Disclosure residual)
- Isolation: no new `UserDefaults.standard` for setup keys

- [x] **Step 1: iOS sheet host + SyncTab Reopen CTA**

- [x] **Step 2: MacUI helpers** (`waitForWindow` + `dismissProviderSetupIfPresent`)

- [x] **Step 3: Smokes** Empty existence sheet; Populated absent; wire dismiss into Empty-Create + ReviewTour Empty

- [x] **Step 4: Run** `bash ./Scripts/ci-test.sh` then `bash ./Scripts/macos-ui-test-remote.sh`

- [x] **Step 5: Commit** `test: XCUI provider setup sheet on empty launch`

---

### Task 6: Isolation Grep + Observability checklist

**Files:** touched sites only

- [x] **Step 1: Full Grep** Setup-Keys + neue Call-Sites: nur `AppSettingsDefaults.current` / isolated suite. Residual `.standard` (Disclosure, SyncTab, CrashCatcher) **nicht** „fixen“, sondern als Residual belassen; kein Continue-XCUI

- [x] **Step 2: Confirm DiagnosticLogger** on present/complete/defer

- [x] **Step 3: `bash ./Scripts/ci-build.sh --arch arm64`** + `bash ./Scripts/ios-test.sh` wenn iOS-Dateien geändert

- [x] **Step 4: Commit** if fixes needed

---

## live_app Checklist (Judge)

- Handler-Trace: Continue → applySelection + notify + markCompleted; Later → markDeferred only; Empty existence smoke ohne Tap; Empty-Create/ReviewTour dismiss via Later
- Isolation-Grep (Setup-Scope) complete; Residual `.standard` dokumentiert
- Identifier uniqueness
- Assert vs Act: kein Continue in ReviewTour/Empty-Create
- Sheet Query: `MacUI.element` / app descendants by identifier
- Compile-Units: Identifier aus SharedUI; keine neuen SwiftUI-Sheet-Types im XCUI-Target
- Hooks: `installOverride` / isolatedDefaults nur Bootstrap/UITesting, Suite-isolierte Unit-Tests
