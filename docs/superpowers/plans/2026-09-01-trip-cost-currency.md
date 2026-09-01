# F13 Trip-Cost Currency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ehrliche Trip-Kostensumme (pro Währung + fehlende Preise) und optionale Umrechnung in die bevorzugte Währung via Frankfurter/ECB-Referenzkurse, inkl. Settings und iOS/macOS-Übersicht.

**Architecture:** Pure `TripCostSummary` in ReisenDomain; Decimal `ExchangeRateQuote`; Mapper in ReisenData; Frankfurter in ReisenAppCore; Settings + Display in ReisenSharedUI; verdrahten in Reisen und ReiseniOS.

**Tech Stack:** Swift 6 / SwiftUI / Swift Testing; URLSession + URLProtocol; UserDefaults; L10n.

## Global Constraints

- No silent fallbacks / mixed-currency sums / unpaired amount+currency as priced.
- FX network only when convert toggle on (default off).
- `ExchangeRateQuote.rates` is `[String: Decimal]`; JSON Double→Decimal only at AppCore boundary.
- SSOT Domain summary; ReisenData maps SD→lines; SharedUI formats only.
- Privacy footer + `docs/legal/privacy.html` (+ EN) in v1.
- TDD per task. Worktree: `.worktrees/feat-f13-trip-cost-currency`.

---

## File map

| File | Role |
|------|------|
| `Sources/ReisenDomain/TripCost/TripCostSummary.swift` | Lines, summary |
| `Sources/ReisenDomain/TripCost/TripCostConversion.swift` | Decimal conversion |
| `Sources/ReisenDomain/Ports/ExchangeRateProviding.swift` | Port |
| `Sources/ReisenDomain/Settings/AppSettings.swift` | Currency keys on `AppSettingsKeys` |
| `Sources/ReisenData/Mapping/TripCostLineMapping.swift` | SD→lines |
| `Sources/ReisenAppCore/ExchangeRates/FrankfurterExchangeRateClient.swift` | HTTP + cache |
| `Sources/ReisenSharedUI/TripCostDisplayText.swift` | Display |
| `Sources/ReisenSharedUI/SettingsView.swift` | Currency section |
| `Sources/Reisen/App/TripDetailView.swift` | Overview |
| `Apps/ReiseniOS/Shared/TripDetailIOS.swift` | Overview |
| `docs/legal/privacy.html`, `en/privacy.html` | FX disclosure |
| L10n + Tests |

---

### Task 1: Domain TripCostSummary (TDD)

- Create: `Sources/ReisenDomain/TripCost/TripCostSummary.swift`
- Create: `Tests/ReisenDomainTests/TripCostSummaryTests.swift`

- [ ] RED: empty; single EUR; EUR+USD separate; missing increments; **amount without currency** and **currency without amount** are not lines (if constructing from optional pairs via factory).
- [ ] Implement `TripCostLine` + `TripCostSummary`.
- [ ] GREEN + commit: `feat(domain): TripCostSummary per currency with missing count`

### Task 2: Conversion + Port (TDD)

- Create: Port + `ExchangeRateQuote` (`Decimal` rates) + conversion
- Create: `Tests/ReisenDomainTests/TripCostConversionTests.swift`

- [ ] RED→GREEN: convert EUR+USD→EUR; missing rate errors; same-currency passthrough.
- [ ] Commit: `feat(domain): convert TripCostSummary with Decimal FX quotes`

### Task 3: AppSettings currency keys (TDD)

- Modify: `Sources/ReisenDomain/Settings/AppSettings.swift` (`AppSettingsKeys`)
- Modify: `Tests/ReisenDomainTests/AppSettingsKeysTests.swift`

- [ ] `preferredCurrencyCode`, `convertAmountsToPreferredCurrency`; Locale default; convert default false.
- [ ] Readers/writers on `AppSettingsKeys` (UserDefaults) — dieselbe SSOT wie SettingsView (View ruft Writer oder schreibt denselben Key-String; Evidence = UserDefaults mit Key-Konstanten, kein Parallel-Pfad).
- [ ] Commit: `feat(settings): preferred currency and convert toggle keys`

### Task 4: ReisenData mapper (TDD)

- Create: `Sources/ReisenData/Mapping/TripCostLineMapping.swift`
- Create: `Tests/ReisenDataTests/TripCostLineMappingTests.swift` (or DomainTests if Data test target pattern differs — use existing Data test target)

- [ ] RED: unpaired rateDetails → missing; gap without pair → missing; mixed currencies → separate lines.
- [ ] Commit: `feat(data): map trip timeline prices to TripCostLine`

### Task 5: Frankfurter client (TDD)

- Create AppCore client + URLProtocol tests
- [ ] Double→Decimal at decode; cache; typed errors.
- [ ] Commit: `feat(appcore): Frankfurter ECB reference rate client with cache`

### Task 6: Display + L10n + Settings entry evidence (TDD)

- Create `TripCostDisplayText`; L10n; Settings section; privacy HTML DE/EN
- Create tests:
  - Display: side-by-side; missing; converted+originals+date; failure keeps originals wording
  - **Entry evidence:** `UserDefaults` mit `AppSettingsKeys` Konstanten (gleicher Pfad wie `@AppStorage`); Readers; Testname `currencySettings_entry_…`.
- Assert privacy HTML contains Frankfurter/ECB (string contains test).
- Commit: `feat(ui): trip cost display, currency settings, privacy note`

### Task 7: Wire macOS + iOS overview

- Replace `tripTotalPriceText`; add iOS overview row; convert async only if toggle on
- [ ] Spy `ExchangeRateProviding`: convert off → 0 Fetches; convert on → ≥1.
- Commit: `feat(ui): trip overview cost summary on macOS and iOS`

### Task 8: Backlog archive

- Move F13 to Umgesetzt with Spec link
- Commit: `docs: archive F13 trip cost currency as implemented`

---

## Verification (Orchestrator)

`bash ./Scripts/ci-test.sh`, `bash ./Scripts/ci-build.sh --arch arm64`, `bash ./Scripts/ci-coverage-diff.sh origin/master`.
