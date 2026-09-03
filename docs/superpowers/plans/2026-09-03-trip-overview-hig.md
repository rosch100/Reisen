# Trip-Overview HIG Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** macOS-Reise-Übersicht mit klarer Hierarchie; iOS nutzt dieselbe `TripOverviewPresentation`; Identifier + XCUI.

**Architecture:** SharedUI Presentation + MacHeader; TripDetailView verdrahtet Cost-Refresh am Wrapper; iOS Section `switch`/`ForEach` über `visibleFields`; neuer L10n-Key `trip.notes`; AppBootstrap skippt CrashCatcher unter UI-Testing.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, XCUI, L10n xcstrings.

**Execution status:** complete (shipped on `feat/trip-overview-hig`, PR #130).

## Global Constraints

- Keine stillen Fallbacks — optionale Blöcke weglassen.
- Dynamic Type Text Styles; Notes nutzen neues `CopyableValueTextStyle.callout`.
- Cost-Semantik unverändert.
- DiagnosticLogger entbehrlich (Layout).
- live_app: CrashCatcher-Skip unter `skipsSideEffects`; vollständiger Isolation-Grep; XCUI Existence-only; Identifier count==1.
- Padding Overview Parent: horizontal 16, vertikal **12**.
- TDD. Worktree: `.worktrees/feat-trip-overview-hig`.
- `bash ./Scripts/ci-test.sh`; UI `bash ./Scripts/macos-ui-test-remote.sh`.

## File map

| File | Role |
| --- | --- |
| `Sources/ReisenSharedUI/TripOverviewPresentation.swift` | SSOT Felder |
| `Sources/ReisenSharedUI/TripOverviewMacHeader.swift` | macOS Header + private Fact-Helper |
| `Sources/ReisenSharedUI/CopyableFieldValue.swift` | `CopyableValueTextStyle.callout` |
| `Sources/ReisenSharedUI/UITestingIdentifiers.swift` | IDs |
| `Sources/ReisenAppCore/AppBootstrap.swift` | Skip CrashCatcher wenn `skipsSideEffects` |
| `Sources/ReisenDomain/Localization/L10nKey.swift` | `tripNotes` |
| Localizable.xcstrings (Ist-Pfad Domain) | DE/EN `trip.notes` |
| `Sources/Reisen/App/TripDetailView.swift` | Wire + Padding 12 |
| `Apps/ReiseniOS/Shared/TripDetailIOS.swift` | visibleFields |
| Tests SharedUI + AppCore + MacUISmoke | Evidence |

---

### Task 1: TripOverviewPresentation (TDD)

**Files:**
- Create: `Sources/ReisenSharedUI/TripOverviewPresentation.swift`
- Create: `Tests/ReisenSharedUITests/TripOverviewPresentationTests.swift`

**Interfaces:**
- Produces: `TripOverviewField`, `TripOverviewPresentation.visibleFields(hasDestination:Bool, hasBookings:Bool, hasNotes:Bool) -> [TripOverviewField]`

- [x] **Step 1: Failing tests** (order full / omits optional / completeness requires bookings) — siehe Spec-Reihenfolge title→destination→period→cost→completeness→notes

- [x] **Step 2:** `swift test --filter tripOverviewPresentation` → FAIL

- [x] **Step 3: Implement**

```swift
import Foundation

public enum TripOverviewField: Equatable, Hashable, Sendable {
    case title, destination, period, cost, completeness, notes
}

public enum TripOverviewPresentation {
    public static func visibleFields(
        hasDestination: Bool,
        hasBookings: Bool,
        hasNotes: Bool
    ) -> [TripOverviewField] {
        var fields: [TripOverviewField] = [.title]
        if hasDestination { fields.append(.destination) }
        fields.append(contentsOf: [.period, .cost])
        if hasBookings { fields.append(.completeness) }
        if hasNotes { fields.append(.notes) }
        return fields
    }
}
```

- [x] **Step 4: GREEN**

- [x] **Step 5: Commit** `feat(ui): TripOverviewPresentation field order SSOT`

---

### Task 1b: AppBootstrap CrashCatcher Skip (TDD)

**Files:**
- Modify: `Sources/ReisenAppCore/AppBootstrap.swift`
- Create: `Tests/ReisenAppCoreTests/AppBootstrapUITestingIsolationTests.swift`

**Interfaces:**
- `init` speichert `uiTesting` und nutzt **denselben** Wert für CrashCatcher-Guard, `makeReadyState(registry:uiTesting:)`, und alle Side-Effect-Observer/Reset-Guards (heute `UITestingMode.fromProcess` → Property).
- Production-Default: `uiTesting: .fromProcess`.
- Optional Closures nur zum Zählen von Install/Flush in Tests.

- [x] **Step 1: RED**

```swift
@Test @MainActor
func appBootstrap_uiTesting_skipsCrashCatcherAndUsesInMemory() {
    var installCount = 0
    var flushCount = 0
    let bootstrap = AppBootstrap(
        registry: .empty,
        uiTesting: .empty,
        crashCatcherInstall: { installCount += 1 },
        crashCatcherFlush: { flushCount += 1 }
    )
    #expect(installCount == 0)
    #expect(flushCount == 0)
    guard case .ready(let container, _, _, _) = bootstrap.state else {
        Issue.record("expected ready in-memory state")
        return
    }
    #expect(!container.configurations.isEmpty)
    #expect(container.configurations.allSatisfy(\.isStoredInMemoryOnly))
}
```

- [x] **Step 2: Implement** — Property `uiTesting`; Guard; `makeReadyState(..., uiTesting:)`; Observer/Reset nutzen `uiTesting.skipsSideEffects` statt `.fromProcess`.

- [x] **Step 3: GREEN**

- [x] **Step 4: Commit** `fix(appcore): skip crash catcher under UI testing`

---

### Task 2: L10n `trip.notes` + callout Style + Identifiers + MacHeader

**Files:**
- Modify: `L10nKey.swift` — `case tripNotes = "trip.notes"`
- Modify: Localizable.xcstrings — DE „Notizen“, EN „Notes“
- Modify: `CopyableFieldValue.swift` — `case callout` in `CopyableValueTextStyle` (swiftUIFont `.callout`; nsFont `.callout`)
- Test: SharedUI-Test für Style-Exhaustiveness oder Font-Mapping wenn Suite existiert; sonst Compile + Identifier-Tests
- Modify: `UITestingIdentifiers.swift` + Tests
- Create: `TripOverviewMacHeader.swift`

**Interfaces:**
- Produces: `tripOverview`, `tripOverviewTitle`; `TripOverviewMacHeader` **ohne** Cost-Hooks

Finale Signatur:

```swift
public struct TripOverviewMacHeader: View {
    public let title: String
    public let destination: String?
    public let periodText: String
    public let costPrimary: String
    public let costSecondary: String?
    public let completeness: TripCompleteness
    public let notes: String?

    public init(
        title: String,
        destination: String?,
        periodText: String,
        costPrimary: String,
        costSecondary: String?,
        completeness: TripCompleteness,
        notes: String?
    ) { ... }

    public var body: some View {
        let fields = TripOverviewPresentation.visibleFields(
            hasDestination: destination.map { !$0.isEmpty } ?? false,
            hasBookings: completeness.hasBookings,
            hasNotes: notes.map { !$0.isEmpty } ?? false
        )
        VStack(alignment: .leading, spacing: 8) {
            ForEach(fields, id: \.self) { field in
                switch field {
                case .title:
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier(UITestingIdentifiers.tripOverviewTitle)
                case .destination:
                    if let destination {
                        Text(destination)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                case .period:
                    overviewFact(label: L10n.string(.tripPeriod), value: periodText)
                case .cost:
                    VStack(alignment: .leading, spacing: 2) {
                        overviewFact(label: L10n.string(.bookingDetailPrice), value: costPrimary)
                        if let costSecondary {
                            Text(costSecondary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .help(costSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                case .completeness:
                    overviewFact(
                        label: L10n.string(.tripCompletenessLabel),
                        value: L10n.tripCompletenessOverviewFactValue(completeness)
                    )
                    .help(L10n.string(.tripCompletenessHelp))
                    TripCompletenessMacDetailCaption(completeness: completeness)
                case .notes:
                    if let notes {
                        CopyableFieldValue(
                            value: notes,
                            kind: .standard,
                            textStyle: .callout,
                            foregroundStyle: .secondary,
                            lineLimit: 4
                        )
                        .accessibilityLabel(L10n.string(.tripNotes))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(UITestingIdentifiers.tripOverview)
    }

    private func overviewFact(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            CopyableFieldValue(
                value: value,
                kind: .standard,
                textStyle: .body,
                lineLimit: 1
            )
        }
    }
}
```

Make `TripOverviewField` already `Hashable` in Task 1.

- [x] **Step 1:** Identifier + L10n tests RED
- [x] **Step 2:** Keys + Identifiers + Header
- [x] **Step 3:** GREEN Identifier/L10n tests
- [x] **Step 4: Commit** `feat(ui): TripOverviewMacHeader, notes L10n, identifiers`

---

### Task 3: Wire TripDetailView

**Files:** `Sources/Reisen/App/TripDetailView.swift`

- [x] Replace `tripOverviewSection` with `TripOverviewMacHeader(...)` + Cost `.onAppear`/`.onChange` am Wrapper
- [x] Parent padding Overview: `.padding(.vertical, 12)` (horizontal 16 bleibt)
- [x] Remove unused private `overviewFact` from TripDetailView
- [x] `bash ./Scripts/ci-build.sh --arch arm64` EXIT 0
- [x] Commit `feat(macos): wire hierarchical trip overview header`

---

### Task 4: iOS consumes Presentation

**Files:** `Apps/ReiseniOS/Shared/TripDetailIOS.swift`

- [x] Compute `fields = TripOverviewPresentation.visibleFields(...)`
- [x] Build Section content by switching fields (title CopyableLabeledValue, destination, period, `TripCostOverviewIOSRows` for `.cost`, `TripCompletenessOverviewRow` for `.completeness`, notes with `L10n.string(.tripNotes)`)
- [x] Empty-bookings Assign-Button bleibt **nach** den Presentation-Feldern
- [x] `bash ./Scripts/ios-test.sh` → EXIT 0
- [x] Commit `feat(ios): drive trip overview rows from TripOverviewPresentation`

---

### Task 5: XCUI + Isolation

**Files:** `Tests/ReisenMacUITests/MacUISmokeTests.swift`

```swift
func testSeededTripShowsOverview() {
    let ui = MacUI.launchPopulated()
    ui.waitForWindow()
    ui.waitFor(UITestingIdentifiers.seededTripRow).click()
    ui.waitFor(UITestingIdentifiers.detail)
    ui.waitFor(UITestingIdentifiers.tripOverview)
    ui.waitFor(UITestingIdentifiers.tripOverviewTitle)
    XCTAssertEqual(ui.app.descendants(matching: .any).matching(identifier: UITestingIdentifiers.tripOverview).count, 1)
    XCTAssertEqual(ui.app.descendants(matching: .any).matching(identifier: UITestingIdentifiers.tripOverviewTitle).count, 1)
}
```

Identifier `tripOverview` am Overview-Wrapper in `TripDetailView` (`.accessibilityElement(children: .contain)`), nicht nur am Header-Root.

- [x] Isolation: vollständiger Grep wie Spec; Diff-Scope: keine neuen Defaults-Sites
- [x] `bash ./Scripts/macos-ui-test-remote.sh` EXIT 0
- [x] `bash ./Scripts/ci-test.sh` EXIT 0
- [x] Commit `test(macos): assert unique trip overview identifiers`

---

## Spec coverage

| Spec | Task |
| --- | --- |
| Presentation SSOT beider Plattformen | 1, 4 |
| MacHeader Typografie | 2, 3 |
| trip.notes L10n | 2, 4 |
| Padding 12 | 3 |
| XCUI Auto-Select + count==1 | 5 |
| Isolation vollständig | 5 |

## Placeholder scan

Keine TBD; Header-Signatur final ohne Hooks.
