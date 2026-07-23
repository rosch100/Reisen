# iOS Cursor Dev Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cursor kann die iOS/iPadOS-App agent-autonom generieren, bauen, im iPad-Simulator starten und per SweetPad/LLDB debuggen — mit Scripts als SSOT und Xcode nur als Fallback.

**Architecture:** XcodeGen (`project.yml`) erzeugt ein gitignored `.xcodeproj` mit Application-Target `ReiseniOS`, das lokale SPM-Produkte (`ReisenAppCore`, `ReisenSharedUI`) linkt. Scripts `generate-ios-project.sh` / `ios-run.sh` / `ios-test.sh` kapseln Generate→Build→Simulator. Cursor-Tasks und SweetPad nutzen denselben Projektstand; Agents rufen nur die Scripts.

**Tech Stack:** XcodeGen, xcodebuild, simctl, SweetPad, CodeLLDB, SourceKit/`buildServer.json`, Bash-Scripts analog `Scripts/ci-test.sh`

## Global Constraints

- Bundle-ID: `de.roschmac.Reisen.ios`
- Default-Simulator: exakt `iPad Pro 13-inch (M5)` via `IOS_SIMULATOR` (kein stiller Fallback)
- Deployment Target iOS ≥ 17
- Kein committed `.xcodeproj` / `buildServer.json`
- Keine hardcodierte Development-Team-ID
- macOS-Pipeline (`Scripts/build-app.sh`, executable `Reisen`) unverändert
- Keine Workarounds/stillen Fallbacks; Fehler = Exit ≠ 0
- iOS Build/Run/Test im Agent-Workflow nur über `Scripts/generate-ios-project.sh`, `Scripts/ios-run.sh`, `Scripts/ios-test.sh`

## File Map

| Path | Responsibility |
|------|----------------|
| `project.yml` | XcodeGen-SSOT für iOS App + Smoke-Tests |
| `Apps/ReiseniOS/Info.plist` | iOS Bundle-/Permission-Metadaten |
| `Apps/ReiseniOS/*.swift` | App-Quellen (bereits vorhanden; bleiben) |
| `Package.swift` | Shared Libraries only; `ReiseniOS` executable entfernen |
| `Tests/ReiseniOSTests/WorkflowSmokeTests.swift` | Minimaler XCTest für `ios-test.sh`-Pipeline |
| `Scripts/generate-ios-project.sh` | XcodeGen prüfen + Projekt erzeugen |
| `Scripts/ios-run.sh` | Generate → build → boot → install → launch |
| `Scripts/ios-test.sh` | Generate → `xcodebuild test` |
| `.gitignore` | Generierte Xcode-/SweetPad-Artefakte |
| `.vscode/extensions.json` | Empfohlene Extensions |
| `.vscode/tasks.json` | Tasks → Scripts |
| `.vscode/launch.json` | SweetPad LLDB attach |
| `.vscode/settings.json` | CodeLLDB → Xcode LLDB |
| `.cursor/rules/ios-cursor-workflow.mdc` | Agent: nur Scripts |
| `docs/dev/ios-cursor.md` | Setup-Leitfaden |
| `README.md` | Kurzer Verweis auf iOS-Cursor-Doku |

---

### Task 1: Package.swift bereinigen + Gitignore + iOS Info.plist

**Files:**
- Modify: `Package.swift`
- Modify: `.gitignore`
- Create: `Apps/ReiseniOS/Info.plist`
- Create: `Tests/ReiseniOSTests/WorkflowSmokeTests.swift`

**Interfaces:**
- Consumes: bestehende Shared-Targets in `Package.swift`
- Produces: kein `ReiseniOS`-Product/Target mehr in SPM; Info.plist Keys für Bundle `de.roschmac.Reisen.ios`; Smoke-Test-Datei bereit für Task 2

- [ ] **Step 1: Write failing smoke test (pipeline contract)**

Create `Tests/ReiseniOSTests/WorkflowSmokeTests.swift`:

```swift
import XCTest
import ReisenDomain

final class WorkflowSmokeTests: XCTestCase {
    func testProviderIDRawValueRoundTrip() {
        let id = ProviderID(rawValue: "check24")
        XCTAssertEqual(id.rawValue, "check24")
    }
}
```

- [ ] **Step 2: Confirm SPM cannot host this test yet**

Run: `swift test --filter WorkflowSmokeTests 2>&1 | tail -20`  
Expected: FAIL / unknown test (Target noch nicht in SPM — gewollt; iOS-Tests laufen später nur über XcodeGen/`ios-test.sh`)

- [ ] **Step 3: Remove ReiseniOS executable from Package.swift**

In `Package.swift` products: delete the line

```swift
.executable(name: "ReiseniOS", targets: ["ReiseniOS"]),
```

In `Package.swift` targets: delete the entire `.executableTarget(name: "ReiseniOS", ...)` block (path `Apps/ReiseniOS`).

Leave `.executable(name: "Reisen", ...)` and all libraries untouched.

- [ ] **Step 4: Extend `.gitignore`**

Append:

```gitignore
# iOS / XcodeGen / SweetPad (generated)
*.xcodeproj/
*.xcworkspace/
!default.xcworkspace
buildServer.json
.sweetpad/
Apps/ReiseniOS/xcuserdata/
```

- [ ] **Step 5: Create `Apps/ReiseniOS/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>de</string>
	<key>CFBundleDisplayName</key>
	<string>Reisen</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>UILaunchScreen</key>
	<dict/>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationPortraitUpsideDown</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>NSCalendarsUsageDescription</key>
	<string>Reisen legt Termine für Stornofristen in deinem Kalender an.</string>
	<key>NSCalendarsFullAccessUsageDescription</key>
	<string>Reisen legt Termine für Stornofristen in deinem Kalender an.</string>
	<key>NSRemindersUsageDescription</key>
	<string>Reisen legt Erinnerungen in deiner Erinnerungen-App an.</string>
	<key>NSRemindersFullAccessUsageDescription</key>
	<string>Reisen benötigt vollen Zugriff auf deine Erinnerungen-App, um Erinnerungen für Stornofristen zu erstellen, zu aktualisieren oder zu entfernen.</string>
	<key>NSUserNotificationsUsageDescription</key>
	<string>Reisen erinnert dich an bevorstehende Stornofristen.</string>
</dict>
</plist>
```

- [ ] **Step 6: Verify macOS SPM still resolves**

Run: `swift package dump-package >/dev/null && swift build --target ReisenDomain`  
Expected: success; `ReiseniOS` appears neither as product nor target in `swift package describe --type json` output.

- [ ] **Step 7: Commit**

```bash
git add Package.swift .gitignore Apps/ReiseniOS/Info.plist Tests/ReiseniOSTests/WorkflowSmokeTests.swift
git commit -m "$(cat <<'EOF'
chore(ios): prepare SPM and plist for XcodeGen app target

Remove SPM ReiseniOS executable so the iOS app lives only in the generated Xcode project.
EOF
)"
```

---

### Task 2: XcodeGen `project.yml` + `generate-ios-project.sh`

**Files:**
- Create: `project.yml`
- Create: `Scripts/generate-ios-project.sh`

**Interfaces:**
- Consumes: `Apps/ReiseniOS/**`, `Apps/ReiseniOS/Info.plist`, local package `.` products `ReisenAppCore`, `ReisenSharedUI`, `ReisenDomain`
- Produces: `Reisen.xcodeproj` (gitignored); scheme `ReiseniOS`; script exit 0 only if project exists

- [ ] **Step 1: Create `project.yml`**

```yaml
name: Reisen
options:
  bundleIdPrefix: de.roschmac
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true
  groupSortPosition: top

packages:
  Reisen:
    path: .

settings:
  base:
    SWIFT_VERSION: "6.0"
    TARGETED_DEVICE_FAMILY: "1,2"

targets:
  ReiseniOS:
    type: application
    platform: iOS
    sources:
      - path: Apps/ReiseniOS
        excludes:
          - "**/*.plist"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: de.roschmac.Reisen.ios
        PRODUCT_NAME: ReiseniOS
        INFOPLIST_FILE: Apps/ReiseniOS/Info.plist
        GENERATE_INFOPLIST_FILE: false
        CURRENT_PROJECT_VERSION: 1
        MARKETING_VERSION: 0.1
        TARGETED_DEVICE_FAMILY: "1,2"
        CODE_SIGN_STYLE: Automatic
        DEVELOPMENT_TEAM: ""
    dependencies:
      - package: Reisen
        product: ReisenAppCore
      - package: Reisen
        product: ReisenSharedUI
    scheme:
      testTargets:
        - ReiseniOSTests

  ReiseniOSTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: Tests/ReiseniOSTests
    dependencies:
      - target: ReiseniOS
      - package: Reisen
        product: ReisenDomain
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: de.roschmac.Reisen.ios.tests
        GENERATE_INFOPLIST_FILE: true

schemes:
  ReiseniOS:
    build:
      targets:
        ReiseniOS: all
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - ReiseniOSTests
```

- [ ] **Step 2: Create `Scripts/generate-ios-project.sh`**

```bash
#!/usr/bin/env bash
# Erzeugt das iOS Xcode-Projekt aus project.yml (XcodeGen SSOT).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Fehler: xcodegen nicht gefunden. Installieren mit: brew install xcodegen" >&2
  exit 1
fi

if [[ ! -f "$ROOT/project.yml" ]]; then
  echo "Fehler: project.yml fehlt im Repo-Root." >&2
  exit 1
fi

xcodegen generate --spec "$ROOT/project.yml" --project "$ROOT"

if [[ ! -d "$ROOT/Reisen.xcodeproj" ]]; then
  echo "Fehler: Reisen.xcodeproj wurde nicht erzeugt." >&2
  exit 1
fi

echo "OK: $ROOT/Reisen.xcodeproj"
```

Make executable: `chmod +x Scripts/generate-ios-project.sh`

- [ ] **Step 3: Run generate (fail path without XcodeGen)**

If `xcodegen` missing: run script → Expected: exit 1, message mentions `brew install xcodegen`.  
If present: continue.

- [ ] **Step 4: Run generate successfully**

Run: `bash ./Scripts/generate-ios-project.sh`  
Expected: stdout contains `OK: .../Reisen.xcodeproj` and directory exists.

- [ ] **Step 5: Sanity-check scheme**

Run: `xcodebuild -list -project Reisen.xcodeproj`  
Expected: Schemes include `ReiseniOS`; Targets include `ReiseniOS` and `ReiseniOSTests`.

- [ ] **Step 6: Commit**

```bash
git add project.yml Scripts/generate-ios-project.sh
git commit -m "$(cat <<'EOF'
feat(ios): add XcodeGen project and generate script

SSOT project.yml produces a gitignored Reisen.xcodeproj for Cursor/SweetPad.
EOF
)"
```

---

### Task 3: `ios-run.sh` (Agent Build & Launch)

**Files:**
- Create: `Scripts/ios-run.sh`

**Interfaces:**
- Consumes: `Scripts/generate-ios-project.sh`, env `IOS_SIMULATOR` (default `iPad Pro 13-inch (M5)`), scheme `ReiseniOS`, bundle id `de.roschmac.Reisen.ios`
- Produces: App running on booted simulator; exit 0 only after successful `simctl launch`

- [ ] **Step 1: Create `Scripts/ios-run.sh`**

```bash
#!/usr/bin/env bash
# Baut und startet ReiseniOS auf dem iOS-Simulator (SSOT für Agent/Cursor).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIMULATOR_NAME="${IOS_SIMULATOR:-iPad Pro 13-inch (M5)}"
SCHEME="ReiseniOS"
BUNDLE_ID="de.roschmac.Reisen.ios"
PROJECT="$ROOT/Reisen.xcodeproj"
DERIVED="$ROOT/DerivedData/ReiseniOS"

bash "$ROOT/Scripts/generate-ios-project.sh"

# Portable UDID parse (BSD sed/grep on macOS; no GNU awk)
UDID="$(xcrun simctl list devices available \
  | grep -F "$SIMULATOR_NAME (" \
  | head -1 \
  | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/')"

if [[ -z "${UDID}" ]]; then
  echo "Fehler: Simulator nicht gefunden: ${SIMULATOR_NAME}" >&2
  echo "Verfügbare Geräte:" >&2
  xcrun simctl list devices available >&2
  exit 1
fi

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED" \
  -configuration Debug \
  build

APP_PATH="$(find "$DERIVED" -path '*/Debug-iphonesimulator/ReiseniOS.app' -type d | head -1)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Fehler: ReiseniOS.app nicht unter DerivedData gefunden." >&2
  exit 1
fi

xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl launch "$UDID" "$BUNDLE_ID"

echo "OK: $BUNDLE_ID auf $SIMULATOR_NAME ($UDID)"
```

Notes for implementer:
- Do **not** pick another simulator if the name is missing.
- `chmod +x Scripts/ios-run.sh`

- [ ] **Step 2: Fail closed on unknown simulator**

Run: `env IOS_SIMULATOR='__does_not_exist__' bash ./Scripts/ios-run.sh`  
Expected: exit 1, lists available devices, does not boot a substitute.

- [ ] **Step 3: Happy path on default iPad**

Run: `bash ./Scripts/ios-run.sh`  
Expected: exit 0, line `OK: de.roschmac.Reisen.ios on iPad Pro 13-inch (M5) (...)`, app visible in Simulator.

- [ ] **Step 4: Commit**

```bash
git add Scripts/ios-run.sh
git commit -m "$(cat <<'EOF'
feat(ios): add ios-run.sh for simulator build and launch

Agent-facing SSOT: generate, build, install, and launch on the pinned iPad simulator.
EOF
)"
```

---

### Task 4: `ios-test.sh`

**Files:**
- Create: `Scripts/ios-test.sh`

**Interfaces:**
- Consumes: `generate-ios-project.sh`, same `IOS_SIMULATOR` default, scheme `ReiseniOS`
- Produces: exit 0 iff `xcodebuild test` succeeds (inkl. `WorkflowSmokeTests`)

- [ ] **Step 1: Create `Scripts/ios-test.sh`**

```bash
#!/usr/bin/env bash
# Führt iOS-Unit-Tests auf dem Simulator aus (SSOT).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIMULATOR_NAME="${IOS_SIMULATOR:-iPad Pro 13-inch (M5)}"
SCHEME="ReiseniOS"
PROJECT="$ROOT/Reisen.xcodeproj"
DERIVED="$ROOT/DerivedData/ReiseniOS"

bash "$ROOT/Scripts/generate-ios-project.sh"

UDID="$(xcrun simctl list devices available \
  | grep -F "$SIMULATOR_NAME (" \
  | head -1 \
  | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/')"

if [[ -z "${UDID}" ]]; then
  echo "Fehler: Simulator nicht gefunden: ${SIMULATOR_NAME}" >&2
  echo "Verfügbare Geräte:" >&2
  xcrun simctl list devices available >&2
  exit 1
fi

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED" \
  -configuration Debug \
  test
```

`chmod +x Scripts/ios-test.sh`

- [ ] **Step 2: Run tests**

Run: `bash ./Scripts/ios-test.sh`  
Expected: `WorkflowSmokeTests.testProviderIDRawValueRoundTrip` passes; exit 0.

- [ ] **Step 3: Commit**

```bash
git add Scripts/ios-test.sh
git commit -m "$(cat <<'EOF'
feat(ios): add ios-test.sh for simulator XCTest runs

Mirrors ios-run simulator selection rules without silent fallbacks.
EOF
)"
```

---

### Task 5: Cursor / VS Code Tooling + Agent-Regel + Doku

**Files:**
- Create: `.vscode/extensions.json`
- Create: `.vscode/tasks.json`
- Create: `.vscode/launch.json`
- Create: `.vscode/settings.json`
- Create: `.cursor/rules/ios-cursor-workflow.mdc`
- Create: `docs/dev/ios-cursor.md`
- Modify: `README.md` (kurzer Verweis)

**Interfaces:**
- Consumes: Scripts from Tasks 2–4; SweetPad scheme `ReiseniOS`
- Produces: One-command human path (Tasks / F5) + documented agent path

- [ ] **Step 1: Create `.vscode/extensions.json`**

```json
{
  "recommendations": [
    "sweetpad.sweetpad",
    "vadimcn.vscode-lldb",
    "swiftlang.swift-vscode"
  ]
}
```

- [ ] **Step 2: Create `.vscode/tasks.json`**

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "iOS: Generate Xcode project",
      "type": "shell",
      "command": "bash ./Scripts/generate-ios-project.sh",
      "options": { "cwd": "${workspaceFolder}" },
      "problemMatcher": []
    },
    {
      "label": "iOS: Run on Simulator",
      "type": "shell",
      "command": "bash ./Scripts/ios-run.sh",
      "options": { "cwd": "${workspaceFolder}" },
      "problemMatcher": []
    },
    {
      "label": "iOS: Test on Simulator",
      "type": "shell",
      "command": "bash ./Scripts/ios-test.sh",
      "options": { "cwd": "${workspaceFolder}" },
      "problemMatcher": []
    },
    {
      "type": "sweetpad",
      "action": "launch",
      "label": "sweetpad: launch",
      "detail": "Build and launch ReiseniOS (SweetPad)",
      "scheme": "ReiseniOS",
      "configuration": "Debug",
      "isBackground": true,
      "problemMatcher": ["$sweetpad-watch"]
    }
  ]
}
```

- [ ] **Step 3: Create `.vscode/launch.json`**

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "sweetpad-lldb",
      "request": "attach",
      "name": "Attach to running app (SweetPad)",
      "preLaunchTask": "sweetpad: launch"
    }
  ]
}
```

- [ ] **Step 4: Create `.vscode/settings.json`**

```json
{
  "lldb.library": "/Applications/Xcode.app/Contents/SharedFrameworks/LLDB.framework/Versions/A/LLDB",
  "sweetpad.xcodegen.autoGenerate": true
}
```

- [ ] **Step 5: Create `.cursor/rules/ios-cursor-workflow.mdc`**

```markdown
---
description: iOS/iPadOS Build/Run/Test nur über SSOT-Scripts
alwaysApply: true
---

# iOS Cursor Workflow

- iOS Build/Run/Test ausschließlich über:
  - `bash ./Scripts/generate-ios-project.sh`
  - `bash ./Scripts/ios-run.sh`
  - `bash ./Scripts/ios-test.sh`
- Kein ad-hoc-`xcodebuild` mit losen Flags im Standard-Agent-Workflow.
- Default-Simulator ist exakt `iPad Pro 13-inch (M5)`; Override nur via `IOS_SIMULATOR`.
- Kein Commit von `*.xcodeproj`, `buildServer.json` oder `.sweetpad/`.
- Xcode GUI nur für Signing, Entitlements, Instruments.
```

- [ ] **Step 6: Write `docs/dev/ios-cursor.md`**

Content must cover:
1. Prerequisites: Xcode, `brew install xcodegen`, recommended Cursor extensions
2. First-time: `bash ./Scripts/generate-ios-project.sh`
3. Agent/CLI: `ios-run.sh` / `ios-test.sh` + `IOS_SIMULATOR`
4. Human debug: SweetPad sidebar / F5; once `SweetPad: Generate Build Server Config`
5. Xcode fallback: open generated `Reisen.xcodeproj`
6. Link to spec `docs/superpowers/specs/2026-07-23-ios-cursor-dev-workflow-design.md`

- [ ] **Step 7: Add README pointer**

In `README.md`, near the existing iOS mention, add a short link to `docs/dev/ios-cursor.md` for Cursor/Simulator workflow. Do not rewrite unrelated README sections.

- [ ] **Step 8: Manual Cursor verification checklist**

1. Install recommended extensions if missing
2. Run Generate task / script
3. Command Palette: SweetPad generate build server config → `buildServer.json` appears and stays untracked
4. F5 / SweetPad launch; set breakpoint on `ReiseniOSApp` body → hits
5. `git status` shows no tracked `.xcodeproj` / `buildServer.json`

- [ ] **Step 9: Commit**

```bash
git add .vscode/extensions.json .vscode/tasks.json .vscode/launch.json .vscode/settings.json \
  .cursor/rules/ios-cursor-workflow.mdc docs/dev/ios-cursor.md README.md
git commit -m "$(cat <<'EOF'
chore(ios): wire Cursor SweetPad tasks and agent rules

Document the generate/run/test SSOT path and keep Xcode as signing fallback.
EOF
)"
```

---

### Task 6: End-to-End Verification (Definition of Done)

**Files:**
- None (verification only)

**Interfaces:**
- Consumes: all previous tasks
- Produces: evidence that spec DoD items 1–5 pass

- [ ] **Step 1: Generate**

Run: `bash ./Scripts/generate-ios-project.sh`  
Expected: `Reisen.xcodeproj` exists

- [ ] **Step 2: Run**

Run: `bash ./Scripts/ios-run.sh`  
Expected: exit 0, app launched on `iPad Pro 13-inch (M5)`

- [ ] **Step 3: Test**

Run: `bash ./Scripts/ios-test.sh`  
Expected: exit 0, smoke test green

- [ ] **Step 4: Shared-module rebuild sanity**

Touch a comment in `Sources/ReisenAppCore/AppBootstrap.swift`, then `bash ./Scripts/ios-run.sh`  
Expected: rebuild succeeds and app launches

- [ ] **Step 5: Git cleanliness**

Run: `git status --short | rg 'xcodeproj|buildServer|\.sweetpad' || true`  
Expected: only untracked/ignored noise — nothing staged/committed for those paths

- [ ] **Step 6: Final note commit (only if verification docs/comments changed)**

If Step 4 left a debug comment, revert it before finishing. No empty commit.

---

## Spec Coverage Self-Review

| Spec requirement | Task |
|------------------|------|
| XcodeGen SSOT `project.yml` | Task 2 |
| `.xcodeproj` not committed / gitignore | Task 1 + 2 |
| Bundle ID `de.roschmac.Reisen.ios` | Task 1 plist + Task 2 |
| Default simulator exact name, no fallback | Task 3 + 4 |
| Scripts generate/run/test | Tasks 2–4 |
| Remove SPM `ReiseniOS` executable | Task 1 |
| SweetPad + CodeLLDB + launch/tasks | Task 5 |
| Agent rule: scripts only | Task 5 |
| Docs `docs/dev/ios-cursor.md` + README | Task 5 |
| DoD generate/run/breakpoint/shared/git | Task 5 Step 8 + Task 6 |
| macOS pipeline unchanged | Task 1 leaves `Reisen` executable |
| No Team-ID hardcode | Task 2 empty `DEVELOPMENT_TEAM` |

## Placeholder / Consistency Check

- Simulator parsing in Task 3 notes BSD `sed` (not GNU awk `match` third arg) — implementer must use the portable snippet.
- Scheme name `ReiseniOS` consistent across scripts, `project.yml`, SweetPad task.
- DerivedData path `DerivedData/ReiseniOS` is local; already covered by `.gitignore` `DerivedData/`.
