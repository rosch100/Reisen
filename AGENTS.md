# Cursor Agents für Reisen

Dieses Repo nutzt Cursor-Agents primär für saubere CI-/Review-Workflows. Die „Agents“ sind nicht Magic, sondern Leitplanken, was in Änderungen erwartet wird.

## Rollen

### CI-Agent (Build/Test)
- Ziel: `./Scripts/ci-test.sh` lokal und im CI zuverlässig ausführen.
- Regel: Wenn CI fehlschlägt, wird erst Root-Cause analysiert (log/stack), dann gefixt.
- Zielpfade: `.github/workflows/ci.yml`, `.github/workflows/codeql.yml`, `.github/workflows/app-store-check.yml`, `Scripts/ci-test.sh`, `Scripts/ci-build.sh`, `Scripts/build-app.sh`.

### Review-Agent (Qualität / Grenzen)
- Ziel: keine Scope-Ausweitung ohne Absprache.
- Fokus: Domain-Grenzen (`ReisenDomain`, `ReisenData`, `ReisenProviders`) und „keine stillen Fallbacks“.

### Security-Agent (Secrets / Supply Chain)
- Ziel: Secrets nie in Logs oder Artefakten ausgeben.
- Fokus: `release.yml`, `Scripts/sign-and-notarize.sh`, `docs/ci/apple-signing.md`.
- Regel: Nur Secrets aus GitHub (`secrets.*`) verwenden; keine Hardcodings.

### AI-Assistenz (Human-in-the-loop)
- Ziel: AI nur als Hilfswerkzeug nutzen; jede Änderung muss vom Menschen verstanden und geprüft werden.
- Regel: Keine autonomen ungeprüften PR-Inhalte oder Kommentare; AI-Empfehlungen sind Hinweise, keine Gate-Kriterien.
- **Issue-Dev:** Bugs (`kind/error`) starten ohne `/approve` bis zum PR; Feature-Requests erst nach `/approve` / `issue-dev/approved`. Merge bleibt menschlich. Labels/Webhooks per Ensure (SSOT Altanis/CI `config/issue-dev/`). Siehe `docs/ci/issue-dev.md`.
- Zielpfade: `AI_POLICY.md`, `.github/copilot-instructions.md` (für Code-Review-Kommentare), `PULL_REQUEST_TEMPLATE.md` (für Kontext/Checklisten).
- Hinweis: Der Beitragende bleibt für Korrektheit und Verständlichkeit verantwortlich.

## Lokale Kommandos (SSOT zu CI)

- Test (CI-parität): `bash ./Scripts/ci-test.sh`
- Produkt-Build (CodeQL, ohne Test-Targets): `bash ./Scripts/ci-build.sh --arch arm64`
- App-Bundle bauen: `bash ./Scripts/build-app.sh --configuration debug|release`
- macOS-UI-Smokes (XCUI, XcodeGen-ReisenMac): `bash ./Scripts/macos-ui-test.sh`
- macOS-UI-Review-Tour (advisory, kein Gate): `bash ./Scripts/macos-ui-review.sh`

## Cursor Cloud (Linux) — Grenzen und lauffähiger Umfang

Cursor Cloud Agents laufen auf **Linux x86_64 (Ubuntu 24.04)** ohne Xcode. Reisen ist eine
**Apple-only** App (Xcode 27, SwiftUI/SwiftData/WebKit/AppKit/UIKit; sogar `ReisenDomain`
importiert `UniformTypeIdentifiers`/`ImageIO`). Daher gilt in Cloud Agents:

- **Nicht lauffähig auf Linux:** `swift build`, `swift test`, `./Scripts/ci-test.sh` (voll),
  `./Scripts/run-app.sh`, iOS-/macOS-Scripts. Diese brauchen macOS + Xcode 27 (CI-Runner `xcode-27`).
- **Lauffähig auf Linux (SSOT-Teilmenge von `ci-test.sh`):** die Python-/Bash-Prüfungen der CI.
  Nützlich für Arbeiten an `Scripts/`, `.github/workflows/` und dem Gmail-Ingress-Tooling:
  - `REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true bash ./Scripts/embed-github-issue-token.sh`
  - `python3 Scripts/tests/check-app-store-check-workflow.py .github/workflows/app-store-check.yml`
  - `python3 -m unittest Scripts/tests/test_coverage_diff.py`
  - `python3 -m unittest Scripts/tests/test_ios_validate_appstore_report.py`
  - `python3 -m unittest discover -s Scripts/tests/ingest-gmail-feedback`
- **Swift-/App-Änderungen** in Cloud Agents nur editieren; Build/Tests auf macOS (lokal oder CI) verifizieren.

Die Cloud-Agent-Umgebung installiert daher nur die Token-Stub-Vorbereitung (idempotent); Python 3 ist im Default-Image vorhanden.

## Referenzen
- `AI_POLICY.md`: Regeln für die Verwendung von AI in Issues, PRs und Reviews
- `.github/copilot-instructions.md`: Regeln, wie (Copilot) Review-Kommentare formuliert sein sollen

