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
- Gate lokal: `bash ./Scripts/ci-test.sh` (UI: zusätzlich `macos-ui-test.sh`).

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
| macOS XCUI | `bash ./Scripts/macos-ui-test.sh` |
| macOS UI-Review | `bash ./Scripts/macos-ui-review.sh` |
| iOS Simulator starten | `bash ./Scripts/ios-run.sh` |
| iOS Simulator testen | `bash ./Scripts/ios-test.sh` |
| iOS Gerät | `bash ./Scripts/ios-run-device.sh` |
| XcodeGen | `bash ./Scripts/generate-ios-project.sh` |

## Referenzen

- `docs/ARCHITECTURE.md` — Module und Grenzen
- `docs/dev/ios-cursor.md` — iOS in Cursor
- `.github/copilot-instructions.md` — Review-Kommentarformat
- `.github/PULL_REQUEST_TEMPLATE.md` — PR-Checkliste
