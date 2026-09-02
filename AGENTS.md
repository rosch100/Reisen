# Cursor Agents für Reisen

Leitplanken für CI, Review und AI — keine parallele Prozess-Wahrheit zu Skills (`/feature-dev`, `/bugfix`). Evidence: Ledger, Shell, Tests.

## `.cursor/` Overlay (projektspezifisch)

Nur Reisen-Spezifika hier; universelle Hygiene bleibt in User-Rules.

| Artefakt | Geltung | Inhalt |
| --- | --- | --- |
| `rules/reisen-logging-and-tests.mdc` | `alwaysApply` | Logging + Tests inkl. XCUI mitliefern |
| `rules/codereview-exclusions.mdc` | `alwaysApply` | Bewusste Token-Einbettung nicht als Finding |
| `rules/reisen-architecture.mdc` | globs: `Sources/**`, `Apps/**`, `Tests/**`, `Package.swift` | Domain-first, Store/Settings/Zeit |
| `rules/reisen-macos-workflow.mdc` | globs: Reisen/SharedUI, MacUITests, build/run/macos-ui/XcodeGen | build/run/XCUI nur via Scripts |
| `rules/ios-cursor-workflow.mdc` | globs: `Apps/ReiseniOS`, `Scripts/ios-*`, XcodeGen, `project.yml` | Run/Test nur via Scripts |
| `rules/reisen-ci-agents.mdc` | globs: `Scripts/**`, `.github/workflows/**` | Script-SSOT, Secrets |
| `skills/reisen-observability-tests/` | Auto bei Feature/Bugfix/Logging-Lücke | Checkliste Logging + Tests |
| `skills/ui-surface-review/` | nach `macos-ui-review.sh` / HIG-Audit | Advisory HIG/AX-Review |

## Rollen

### CI
- Root-Cause vor Fix; Scripts nicht in YAML duplizieren.
- Gate lokal: `bash ./Scripts/ci-test.sh`. UI-Diff: Agents **müssen** `bash ./Scripts/macos-ui-test-remote.sh` (iMac) nutzen; `macos-ui-test.sh` lokal nur nach nachgewiesenem Remote-Ausfall.
- Pflicht-Check auf GitHub: Aggregator-Job **`CI`** (parallele Suites + Selection — `docs/ci/README.md`, `docs/superpowers/plans/2026-09-02-reisen-ci-performance.md`).

### Review
- Domain-Grenzen und keine stillen Fallbacks.
- Logging/Tests im Diff prüfen (Rule + Skill oben).
- Token-Einbettung: siehe `codereview-exclusions.mdc`.

### Security
- Keine Secrets in Logs/Artefakten/Tree; nur `secrets.*` bzw. dokumentierte Embed-Pfade (`docs/ci/github-issues-token.md`).

### AI (Human-in-the-loop)
- `AI_POLICY.md`: AI ist Hilfswerkzeug; Merge bleibt menschlich.
- Issue-Dev: Bugs ohne `/approve` bis PR; Features nach `/approve`. Labels/Webhooks/Ensure: SSOT `docs/ci/issue-dev.md` (Altanis/CI `config/issue-dev/`).

## Lokale Kommandos (SSOT)

| Zweck | Befehl |
| --- | --- |
| Tests (CI-parität) | `bash ./Scripts/ci-test.sh` |
| Produkt-Build | `bash ./Scripts/ci-build.sh --arch arm64` |
| macOS bauen | `bash ./Scripts/build-app.sh` |
| macOS starten | `bash ./Scripts/run-app.sh` |
| macOS XCUI (Agents, iMac) | `bash ./Scripts/macos-ui-test-remote.sh` |
| macOS XCUI (lokal, nur Fallback) | `bash ./Scripts/macos-ui-test.sh` |
| macOS UI-Review | `bash ./Scripts/macos-ui-review.sh` |
| iOS Simulator starten | `bash ./Scripts/ios-run.sh` |
| iOS Simulator testen | `bash ./Scripts/ios-test.sh` |
| iOS Gerät | `bash ./Scripts/ios-run-device.sh` |
| XcodeGen | `bash ./Scripts/generate-ios-project.sh` |

## Cursor Cloud (Linux) — Grenzen und lauffähiger Umfang

Cursor Cloud Agents laufen auf **Linux x86_64 (Ubuntu 24.04)** ohne Xcode. Reisen ist eine
**Apple-only** App (Xcode 27, SwiftUI/SwiftData/WebKit/AppKit/UIKit; sogar `ReisenDomain`
importiert `UniformTypeIdentifiers`/`ImageIO`). Daher gilt in Cloud Agents:

- **Nicht lauffähig auf Linux:** `swift build`, `swift test`, `./Scripts/ci-test.sh` (voll),
  `./Scripts/run-app.sh`, iOS-/macOS-Scripts. Diese brauchen macOS + Xcode 27 (CI-Runner `xcode-27`).
- **Lauffähig auf Linux (SSOT-Teilmenge von `ci-test.sh`):** die Python-/Bash-Prüfungen der CI.
  Nützlich für Arbeiten an `Scripts/`, `.github/workflows/` und dem Gmail-Ingress-Tooling:
  - `REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true bash ./Scripts/embed-github-issue-token.sh`
  - `python3 -m unittest discover -s Scripts/tests -p 'test_ci_*.py'`
  - `python3 Scripts/tests/check-app-store-check-workflow.py .github/workflows/app-store-check.yml`
  - `python3 -m unittest Scripts/tests/test_coverage_diff.py`
  - `python3 -m unittest Scripts/tests/test_ios_validate_appstore_report.py`
  - `python3 -m unittest discover -s Scripts/tests/ingest-gmail-feedback`
- **Swift-/App-Änderungen** in Cloud Agents nur editieren; Build/Tests auf macOS (lokal oder CI) verifizieren.

Die Cloud-Agent-Umgebung installiert daher nur die Token-Stub-Vorbereitung (idempotent); Python 3 ist im Default-Image vorhanden.

## Referenzen

- `docs/ARCHITECTURE.md` — Module und Grenzen
- `docs/dev/ios-cursor.md` — iOS in Cursor
- `.github/copilot-instructions.md` — Review-Kommentarformat
- `.github/PULL_REQUEST_TEMPLATE.md` — PR-Checkliste
