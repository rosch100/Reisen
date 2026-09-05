# Reisen CI-Performance (2026-09-02)

> Cursor-Plan (Ausführungsdetail): `~/.cursor/plans/reisen_ci_performance_optimierung_b04de0ed.plan.md`
> Folge: CI-Beschleunigung Selection + Full-Wall (2026-09-05) — `~/.cursor/plans/ci_speed_optimization_023adb14.plan.md`
> Code-SSOT: `.github/workflows/ci.yml`, `Scripts/ci-select-suites.py`, `Scripts/ci-enforce-suite-gate.py`, `Scripts/ios-build-release-check.sh`

**Goal:** Pflicht-CI-Wall ([`ci.yml`](../../.github/workflows/ci.yml)) von ~22–23 min auf typisch unter ~12 min Compute (Full); Domain/Provider-PRs oft unter ~5 min via Suite-Selection — Isolation/XCUI streng.

**Architecture:** `detect-suites` (Ubuntu, `fetch-depth: 0`) → Selection-Artifact; parallele Suite-Jobs (`xcode-27`, `fetch-depth: 1`); Aggregator **`CI`** (`if: always()`). Scripts bleiben SSOT.

## Global Constraints

- Merge-Check-Name bleibt `CI`.
- `push`/`master` und Harness-Touch → `full`.
- Fail-closed: API-Fehler / unmapped / Harness / push-master → `full`. Fehlende PR-Branch-Greens: Default-Branch-Baseline (`master` Last-Green, sonst `origin/master`-SHA) auffüllen; nur wenn auch das unmöglich → `full` (`no-last-green`).
- Store/Private Simulator-**Tests** nicht parallel auf demselben Simulator-UDID (v1: serial). Release-Isolation-**Builds** parallel mit `generic/platform=iOS Simulator` (kein Sim-Boot).
- `permissions`: `contents: read`, `actions: read`.
- Remessung: Queue vs. Compute getrennt ausweisen; Log `reisen-ci-selection:` inkl. `baselineSource=`.
- Default-Branch-Baseline: `origin/$GITHUB_BASE_REF` / `origin/master` / `master` (erster treffender Ref); Ref wird geloggt.

## Suites

| Job | Script |
| --- | --- |
| `suite-swiftpm` | `Scripts/ci-test.sh` |
| `suite-ios-sim` | `Scripts/ios-test.sh` |
| `suite-ios-release` | `Scripts/ios-build-release-check.sh` |
| `suite-macos-ui` | `Scripts/macos-ui-test.sh` |

## Path→Suite (Kurz)

| Pfad | Suites |
| --- | --- |
| nur Docs/Root-Markdown Allowlist | `empty-allowed` |
| Harness / `Package.swift` / unmapped `Scripts/` / `.github/` | `full` |
| Domain/Data/Providers/… | `swiftpm` |
| `Sources/ReisenSharedUI/**` | alle |
| `Sources/Reisen/**` | `swiftpm` + `macos-ui` |
| `Apps/ReiseniOS*` | `ios-sim` + `ios-release` |
| `Apps/Shared/**`, MacUITests | `macos-ui` |

## Gate

- Selected → muss `success`
- Unselected → `skipped` (oder harmlos `success`)
- Alle skipped nur bei `empty-allowed`/`docs-only`
- Fehlendes `selection.json` → rot

## Baseline (vor Optimierung)

[`33654883337`](https://github.com/rosch100/Reisen/actions/runs/33654883337), [`33649824402`](https://github.com/rosch100/Reisen/actions/runs/33649824402): ~22–23 min serial.

Vor Selection-Fix (2026-09-05): Full-Wall typisch ~14–25 min; viele PRs `mode=full reason=no-last-green` (PR-Branch ohne Greens).

## Remessung (nach CI)

| Lauf | Run-URL | Compute-Wall | Queue | mode / baselineSource |
| --- | --- | --- | --- | --- |
| Full (Harness-PR / push-master) | _pending_ | Ziel unter 12 min | _pending_ | `full` |
| Domain/Provider-PR (nicht Harness) | _pending_ | Ziel unter 5 min | _pending_ | `affected` + `baselineSource=master` (o. Ä.) |
| Docs-only Folge | _pending_ | ~Detect+Gate | _pending_ | `empty-allowed` |

Lokale Contract-Evidence (2026-09-05): `python3 -m unittest discover -s Scripts/tests -p 'test_ci_*.py'`; `bash ./Scripts/ios-build-release-check.sh --self-test`; Offline-Sim Domain+Master-Baseline → `affected` / nur `suite-swiftpm`. Phase C (ios-sim parallel / XcodeGen-Cache) **nicht** gestartet — erst wenn GitHub Full-Wall nach A+B noch ≥12 min. Erster Full-Lauf auf `xcode-27` muss `reisen-ci-duration` und `DerivedData/ios-release-check-*/xcodebuild-release.log` gegen Ziel unter 12 min prüfen (generic destination + Parallel-Builds).

## Out of Scope

CodeQL, App-Store-Check, Linux-Swift, Idelun-Store-Port. Scheme-Parallel für `ios-test` ohne zweiten Simulator-UDID (Phase C nur nach Remessung, wenn Full-Wall noch ≥12 min).
