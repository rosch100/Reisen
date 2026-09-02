# Reisen CI-Performance (2026-09-02)

> Cursor-Plan (Ausführungsdetail): `~/.cursor/plans/reisen_ci_performance_optimierung_b04de0ed.plan.md`
> Code-SSOT: `.github/workflows/ci.yml`, `Scripts/ci-select-suites.py`, `Scripts/ci-enforce-suite-gate.py`

**Goal:** Pflicht-CI-Wall ([`ci.yml`](../../.github/workflows/ci.yml)) von ~22–23 min auf typisch unter ~12 min Compute (Full); Folge-Pushes oft darunter via Suite-Selection — Isolation/XCUI streng.

**Architecture:** `detect-suites` (Ubuntu, `fetch-depth: 0`) → Selection-Artifact; parallele Suite-Jobs (`xcode-27`, `fetch-depth: 1`); Aggregator **`CI`** (`if: always()`). Scripts bleiben SSOT.

## Global Constraints

- Merge-Check-Name bleibt `CI`.
- `push`/`master` und Harness-Touch → `full`.
- Fail-closed: kein Last-Green / unmapped / API-Fehler → `full`.
- Store/Private nicht parallel auf demselben Simulator-UDID (v1: serial).
- `permissions`: `contents: read`, `actions: read`.
- Remessung: Queue vs. Compute getrennt ausweisen.

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

## Remessung (nach CI)

| Lauf | Run-URL | Workflow-Wall | Längste Suite (Compute) | mode |
| --- | --- | --- | --- | --- |
| Full (PR #122, erster Lauf) | [33658814825](https://github.com/rosch100/Reisen/actions/runs/33658814825) | **~14,5 min** (17:04–17:19 UTC) | `suite-ios-release` **~14,2 min**; `ios-sim` ~10,8 min; `swiftpm` ~3,5 min; `macos-ui` ~4,1 min (Start +~3,5 min Queue) | `full` (kein Last-Green) |
| Docs-only Folge | _pending_ | _pending_ | n/a (Suites skipped erwartet) | `empty-allowed` erwartet |

Baseline serial war ~22–23 min. Full parallel: ~14,5 min Wall (**−~8 min**). Ziel &lt;~12 min Compute noch nicht erreicht (`ios-release` dominiert); Queue sichtbar bei `macos-ui`.

## Out of Scope

CodeQL, App-Store-Check, Linux-Swift, Idelun-Store-Port, Scheme-Parallel ohne 2. Simulator.
