# iCloud Sync Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In-App Opt-out-Toggle für CloudKit-Sync (Default an), Live-Reopen des Hybrid-Stores, optional Wipe beim Ausschalten — Spec `docs/superpowers/specs/2026-09-04-icloud-sync-toggle-design.md`.

**Architecture:** Preference in `AppSettingsKeys` (fehlender Key = an). `PersistenceBootstrap.isCloudKitEnabled(... iCloudSyncPreferenceEnabled:)` und `isCloudKitEnabledByEnvironment(iCloudSyncPreferenceEnabled:)` multiplizieren Env-Gate × Preference; Preference wird **außerhalb** von ReisenData aufgelöst und injiziert. `AppBootstrap.applyICloudSyncPreference(enabled:wipeCloud:)` öffnet den Container live neu (Reuse Reset-/Wipe-Pfad). SharedUI-Toggle + Confirms; Hosts verdrahten Callback.

**Tech Stack:** Swift / SwiftData / SwiftUI, Swift Testing, macOS XCUI, `DiagnosticLogger`, `AppSettingsDefaults`.

## Global Constraints

- Settings-Keys nur über `AppSettingsKeys` / `AppSettingsDefaults.current`.
- Preference **nicht** in CloudKit; lokal only.
- Default: fehlender Key ⇒ Sync erlaubt (`true`).
- Env-Hard-Off (`REISEN_CLOUDKIT=0`, CI, Entitlements) bleibt dominant; Toggle dann disabled.
- Keine stillen Fallbacks; bei Apply-Fail Preference revertieren (außer nach erfolgreichem Cloud-Wipe).
- Logging + Tests im selben Diff (`reisen-observability-tests`).
- Identifier-SSOT: `UITestingIdentifiers`; Agents-UI: `bash ./Scripts/macos-ui-test-remote.sh`.
- Worktree: `/Users/roschmac/Entwicklung/Reisen/.worktrees/feat-icloud-sync-toggle`, Branch `feat/icloud-sync-toggle`.

## File map

| File | Responsibility |
| --- | --- |
| `Sources/ReisenDomain/Settings/AppSettings.swift` | Key + `isICloudSyncEnabled` / `setICloudSyncEnabled` |
| `Sources/ReisenData/Schema/PersistenceBootstrap+CloudKitEnv.swift` | Preference-Parameter am Gate; kein `AppSettingsKeys`-Read in Data |
| `Sources/ReisenAppCore/AppBootstrap.swift` | `applyICloudSyncPreference` + Diagnostics |
| `Sources/ReisenAppCore/GitHubIssues/RuntimeEnvironmentSnapshot.swift` | Effective iCloud an/aus inkl. Preference |
| `Sources/ReisenSharedUI/SettingsView.swift` | Toggle + Confirms + disabled bei Env-off |
| `Sources/ReisenSharedUI/UITestingIdentifiers.swift` | `settingsICloudSyncToggle` |
| `Sources/ReisenDomain/Localization/L10nKey.swift` + `Localizable.xcstrings` | Confirm-/Footer-Strings |
| `Sources/Reisen/Reisen.swift` | Settings-Callback |
| `Apps/ReiseniOS/Shared/MoreTab.swift` + `ReiseniOSApp.swift` | iOS-Callback |
| `docs/dev/swiftdata-hybrid-cloudkit.md` | Gate dokumentieren |
| `docs/legal/privacy.html` + `docs/legal/en/privacy.html` | Abwahl in Einstellungen |
| Tests Domain / Data / AppCore / SharedUI / MacUISmoke | Spec-Asserts |

---

### Task 1: Domain Preference API (TDD)

**Files:**
- Modify: `Sources/ReisenDomain/Settings/AppSettings.swift`
- Modify: `Tests/ReisenDomainTests/AppSettingsKeysTests.swift`

**Interfaces:**
- Produces:
  - `AppSettingsKeys.icloudSyncEnabled` = `"reisen_icloudSyncEnabled"`
  - `AppSettingsKeys.isICloudSyncEnabled(defaults: UserDefaults = AppSettingsDefaults.current) -> Bool`
  - `AppSettingsKeys.setICloudSyncEnabled(_ enabled: Bool, defaults: UserDefaults = AppSettingsDefaults.current)`

- [ ] **Step 1: Write failing tests** in `AppSettingsKeysTests.swift`:

```swift
@Test func icloudSyncEnabledKey_isStableAndPrefixed() {
    #expect(AppSettingsKeys.icloudSyncEnabled == "reisen_icloudSyncEnabled")
}

@Test func isICloudSyncEnabled_defaultsToTrueWhenUnset() {
    let suite = "ReisenTests.icloudSyncEnabled"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    #expect(AppSettingsKeys.isICloudSyncEnabled(defaults: defaults) == true)
    AppSettingsKeys.setICloudSyncEnabled(false, defaults: defaults)
    #expect(AppSettingsKeys.isICloudSyncEnabled(defaults: defaults) == false)
    AppSettingsKeys.setICloudSyncEnabled(true, defaults: defaults)
    #expect(AppSettingsKeys.isICloudSyncEnabled(defaults: defaults) == true)
}
```

- [ ] **Step 2: Run**

```bash
cd /Users/roschmac/Entwicklung/Reisen/.worktrees/feat-icloud-sync-toggle
swift test --filter icloudSyncEnabled
```

Expected: FAIL (missing symbols)

- [ ] **Step 3: Implement** in `AppSettings.swift` (neben anderen Keys):

```swift
/// Nutzer erlaubt CloudKit-Mirroring (Opt-out: fehlender Key = an).
public static let icloudSyncEnabled = "reisen_icloudSyncEnabled"

public static func isICloudSyncEnabled(defaults: UserDefaults = AppSettingsDefaults.current) -> Bool {
    guard defaults.object(forKey: icloudSyncEnabled) != nil else { return true }
    return defaults.bool(forKey: icloudSyncEnabled)
}

public static func setICloudSyncEnabled(_ enabled: Bool, defaults: UserDefaults = AppSettingsDefaults.current) {
    defaults.set(enabled, forKey: icloudSyncEnabled)
}
```

- [ ] **Step 4: Run filter** Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenDomain/Settings/AppSettings.swift Tests/ReisenDomainTests/AppSettingsKeysTests.swift
git commit -m "feat(domain): iCloud sync preference key (default on)"
```

---

### Task 2: CloudKit Env-Gate × Preference (TDD)

**Files:**
- Modify: `Sources/ReisenData/Schema/PersistenceBootstrap+CloudKitEnv.swift`
- Create: `Tests/ReisenDataTests/CloudKitPreferenceGateTests.swift`

**Interfaces:**
- Consumes: Preference-Bool vom Aufrufer (`AppSettingsKeys.isICloudSyncEnabled` in AppCore/SharedUI/Verification)
- Produces: `isCloudKitEnabled(..., iCloudSyncPreferenceEnabled: Bool)` — wenn Preference `false` ⇒ `false`; `isCloudKitEnabledByEnvironment(iCloudSyncPreferenceEnabled:)` nimmt denselben Wert (kein Domain-Import in CloudKitEnv)
- Produces: `isCloudKitAllowedByEnvironmentProcess()` für UI-disabled (Env only)

```swift
nonisolated public static func isCloudKitAllowedByEnvironment(
    environment:..., processName:..., arguments:..., teamIdentifier:...,
    applicationIdentifier:..., icloudContainerIdentifiers:...,
    icloudServices:..., icloudContainerEnvironment:...
) -> Bool
// bisheriger Body von isCloudKitEnabled ohne Preference

nonisolated public static func isCloudKitEnabled(
    ...same...,
    iCloudSyncPreferenceEnabled: Bool
) -> Bool {
    guard iCloudSyncPreferenceEnabled else { return false }
    return isCloudKitAllowedByEnvironment(...)
}

nonisolated public static func isCloudKitEnabledByEnvironment(
    iCloudSyncPreferenceEnabled: Bool
) -> Bool {
    isCloudKitEnabled(
        ...,
        iCloudSyncPreferenceEnabled: iCloudSyncPreferenceEnabled
    )
}

nonisolated public static func isCloudKitAllowedByEnvironmentProcess() -> Bool {
    isCloudKitAllowedByEnvironment(... current process entitlements ...)
}
```

- [ ] **Step 1: Failing tests** — Env würde erlauben, Preference false ⇒ false; Preference true + `REISEN_CLOUDKIT=0` ⇒ false:

```swift
@Test func cloudKitGate_respectsPreferenceOff() {
    let allowed = PersistenceBootstrap.isCloudKitEnabled(
        environment: [:],
        processName: "Voyenna",
        arguments: [],
        teamIdentifier: "TEAM",
        applicationIdentifier: "TEAM.app.voyenna.reisen",
        icloudContainerIdentifiers: [PersistenceBootstrap.cloudKitContainerID],
        icloudServices: ["CloudKit"],
        icloudContainerEnvironment: "Development",
        iCloudSyncPreferenceEnabled: false
    )
    #expect(allowed == false)
}

@Test func cloudKitGate_envZeroDominatesEvenIfPreferenceOn() {
    let allowed = PersistenceBootstrap.isCloudKitEnabled(
        environment: ["REISEN_CLOUDKIT": "0"],
        processName: "Voyenna",
        arguments: [],
        teamIdentifier: "TEAM",
        applicationIdentifier: "TEAM.app.voyenna.reisen",
        icloudContainerIdentifiers: [PersistenceBootstrap.cloudKitContainerID],
        icloudServices: ["CloudKit"],
        icloudContainerEnvironment: "Development",
        iCloudSyncPreferenceEnabled: true
    )
    #expect(allowed == false)
}
```

Hinweis: Auf Linux/Cloud-Agent laufen Swift-Tests nicht; lokal/macOS. Bestehende Call-Sites von `isCloudKitEnabled(` ohne Preference-Parameter müssen alle auf die neue Signatur umgestellt werden (`rg isCloudKitEnabled`).

- [ ] **Step 2: Run** `swift test --filter CloudKitPreferenceGateTests` Expected: FAIL

- [ ] **Step 3: Implement** refactor + Preference-AND; `import` Domain bereits vorhanden

- [ ] **Step 4: PASS** inkl. ggf. angepasste bestehende Tests

- [ ] **Step 5: Commit** `feat(data): CloudKit gate respects iCloud sync preference`

---

### Task 3: AppBootstrap.applyICloudSyncPreference + Logging (TDD)

**Files:**
- Modify: `Sources/ReisenAppCore/AppBootstrap.swift`
- Modify: `Sources/ReisenAppCore/GitHubIssues/RuntimeEnvironmentSnapshot.swift` (effective flag bleibt `isCloudKitEnabledByEnvironment()` — deckt Preference ab)
- Create: `Tests/ReisenAppCoreTests/ICloudSyncPreferenceApplyTests.swift`

**Interfaces:**
- Produces:

```swift
public func applyICloudSyncPreference(enabled: Bool, wipeCloud: Bool)
```

Semantik laut Spec:

1. Guard `!isResetting`; set `isResetting = true`
2. Merke `previous = AppSettingsKeys.isICloudSyncEnabled()`
3. reason: `user_enable` | `user_disable_keep_local` | `user_disable_wipe`
4. `DiagnosticLogger` `component: "ICloudSyncPreference"`, `phase: "apply"`, `event: apply_started`
5. `stopCloudSideEffectObserverIfReady()`
6. UITesting `skipsSideEffects`: Preference schreiben + `activateReadyState()`; success log; return
7. Wenn `!enabled && wipeCloud`: Wipe **zuerst** mit Preference noch an (failed-store Provisional braucht CloudKit); danach Preference `false`, immer `activateReadyState()` lokal-only. Nach erfolgreichem Wipe Preference bei Reopen-Fehler **nicht** revertieren
8. Wenn Keep-Local / Enable: Preference schreiben, dann `activateReadyState()` (`makeContainer(cloudKitEnabled:)` mit Effective Gate)
9. success log; bei catch: Preference auf `previous` revertieren **außer** nach erfolgreichem Wipe, `state = .failed`, `apply_failed`

- [ ] **Step 1: Failing unit test** — In-Memory bootstrap: apply false keep-local ändert Preference und bleibt `.ready`; apply true setzt Preference an. (Kein echtes CloudKit.)

```swift
@MainActor
@Test func applyICloudSyncPreference_keepLocal_setsPreferenceOff() throws {
    let suite = "ReisenTests.applyICloud.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    AppSettingsDefaults.installOverride(defaults)
    defer { AppSettingsDefaults.installOverride(nil) }

    let bootstrap = AppBootstrap(registry: .empty, uiTesting: .empty)
    bootstrap.applyICloudSyncPreference(enabled: false, wipeCloud: false)
    // wait briefly for Task if async — prefer synchronous internal perform if extracted
    #expect(AppSettingsKeys.isICloudSyncEnabled(defaults: defaults) == false)
    guard case .ready = bootstrap.state else {
        Issue.record("expected ready")
        return
    }
}
```

Wenn Apply async wie Reset: Test mit `await` auf fertigem `performApply` oder `confirmation`/`spin` bis `!isResetting`. Bevorzugt private `performApply` async und public wrapper wie `resetStoreAndRetry`.

- [ ] **Step 2: Run filter** Expected: FAIL

- [ ] **Step 3: Implement** Apply + Diagnostics

- [ ] **Step 4: PASS + Commit** `feat(appcore): live apply iCloud sync preference`

---

### Task 4: SharedUI Toggle + L10n + Identifiers

**Files:**
- Modify: `Sources/ReisenSharedUI/SettingsView.swift`
- Modify: `Sources/ReisenSharedUI/UITestingIdentifiers.swift`
- Modify: `Sources/ReisenDomain/Localization/L10nKey.swift`
- Modify: `Sources/ReisenDomain/Resources/Localizable.xcstrings`
- Modify: `Tests/ReisenSharedUITests/UITestingIdentifiersTests.swift`

**Interfaces:**
- Consumes: `onApplyICloudSyncPreference: ((Bool, Bool) -> Void)?` — `(enabled, wipeCloud)`
- Consumes: `cloudKitAllowedByEnvironment: Bool` (Init-Parameter oder Computed via `PersistenceBootstrap.isCloudKitAllowedByEnvironmentProcess()`)
- Produces: Toggle ID `reisen.settings.icloud-sync-toggle`

L10n (DE/EN) Keys (neu):

| Key | DE | EN |
| --- | --- | --- |
| `settings.icloud.disable_title` | iCloud-Sync ausschalten? | Turn off iCloud sync? |
| `settings.icloud.disable_message` | Sync stoppt auf diesem Gerät. iCloud-Daten bleiben, bis du sie leerst — bei erneutem Einschalten können sie zurückkommen. | Sync stops on this device. iCloud data remains until you wipe it — turning sync back on may restore it. |
| `settings.icloud.disable_keep_local` | Nur Sync stoppen | Stop sync only |
| `settings.icloud.disable_wipe` | Sync stoppen und iCloud leeren | Stop sync and wipe iCloud |
| `settings.icloud.enable_title` | iCloud-Sync einschalten? | Turn on iCloud sync? |
| `settings.icloud.enable_message` | Reisen und Buchungen können von anderen Geräten mit demselben iCloud-Account geladen werden. | Trips and bookings may load from other devices using the same iCloud account. |
| `settings.icloud.env_forced_off_footer` | CloudKit ist in dieser Umgebung deaktiviert (z. B. Tests oder `REISEN_CLOUDKIT=0`). | CloudKit is disabled in this environment (e.g. tests or `REISEN_CLOUDKIT=0`). |

Status-Text `settings.icloud.status.available` anpassen: „Sync aktiv“ nur wenn Preference an; sonst „Sync vom Nutzer deaktiviert“ (neue Keys optional).

UI-Flow:
- `@AppStorage(AppSettingsKeys.icloudSyncEnabled)` mit Default-Problem: `@AppStorage` behandelt fehlenden Key als false. **Nicht** roh `@AppStorage` für Opt-out-Default. Stattdessen Binding über `AppSettingsKeys.isICloudSyncEnabled` / `setICloudSyncEnabled` + `@State` synced in `.task`/onAppear, oder Wrapper der fehlenden Key als true mapped.
- Toggle onChange → Confirms; Cancel stellt `@State` zurück.
- Call `onApplyICloudSyncPreference?(enabled, wipe)`.

- [ ] **Step 1: Identifiers + L10n + identifier test**

- [ ] **Step 2: SettingsView Toggle + dialogs + Init-Callback**

- [ ] **Step 3: Compile** `bash ./Scripts/ci-build.sh --arch arm64` (oder Package-Filter SharedUI)

- [ ] **Step 4: Commit** `feat(ui): settings toggle for iCloud sync preference`

---

### Task 5: Host wiring (macOS + iOS)

**Files:**
- Modify: `Sources/Reisen/Reisen.swift`
- Modify: `Apps/ReiseniOS/Shared/MoreTab.swift`
- Modify: `Apps/ReiseniOS/Shared/ReiseniOSApp.swift` (Callback durchreichen)

```swift
SettingsView(
    ...
    onApplyICloudSyncPreference: { enabled, wipe in
        bootstrap?.applyICloudSyncPreference(enabled: enabled, wipeCloud: wipe)
    }
)
```

Nach Apply: Settings-Window muss neues `modelContainer` bekommen — da `bootstrap.state` `@Observable` wechselt, Settings-Body neu bauen (bereits `if case .ready(let container...)`).

- [ ] **Step 1: Wire macOS + iOS**

- [ ] **Step 2: `bash ./Scripts/ci-build.sh --arch arm64`** (+ optional `ios-test.sh` compile)

- [ ] **Step 3: Commit** `feat: wire iCloud sync preference apply on macOS and iOS`

---

### Task 6: Docs + XCUI Smoke + CI gate

**Files:**
- Modify: `docs/dev/swiftdata-hybrid-cloudkit.md` — Absatz Preference-Gate + Live-Reopen
- Modify: `docs/legal/privacy.html` + `docs/legal/en/privacy.html` — Sync in App-Einstellungen abwählbar
- Modify: `Tests/ReisenMacUITests/MacUISmokeTests.swift` — nach `openSettings()` auch `settingsICloudSyncToggle` waitFor
- Modify: Status-L10n falls Task 4 offen

- [ ] **Step 1: Docs patches**

- [ ] **Step 2: XCUI assert** Toggle existiert (UITesting setzt `REISEN_CLOUDKIT=0` → Toggle disabled ok, muss trotzdem existieren)

- [ ] **Step 3: `bash ./Scripts/ci-test.sh`**

- [ ] **Step 4: `bash ./Scripts/macos-ui-test-remote.sh`** (UI-Diff)

- [ ] **Step 5: Commit** `test+docs: iCloud sync toggle smoke and privacy note`

---

## Spec coverage checklist

| Spec-Anforderung | Task |
| --- | --- |
| Key + Default an | 1 |
| Env × Preference Gate | 2 |
| Live Apply keep-local / wipe / enable + revert on fail + logging | 3 |
| Toggle + Confirms C + Identifier | 4 |
| Hosts | 5 |
| Docs Privacy/Hybrid + XCUI + ci-test | 6 |
| Nicht CloudKit-Preference-Mirror | (out of scope) |

## Self-review notes

- `@AppStorage` Default-Falle dokumentiert in Task 4 — Binding über SSOT-Helfer Pflicht.
- Keep-local **ohne** `resetStoreFiles`, außer Open schlägt fehl (dann bestehender Wipe-once-Retry in `makeContainer`).
- Alle `isCloudKitEnabled(` Call-Sites Signatur-Update in Task 2.
