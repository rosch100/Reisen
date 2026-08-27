# CI für Reisen

Dieser Ordner dokumentiert die CI/CD-Infrastruktur im Repo.

## Verfügbare Workflows

- `ci.yml`: Build+Test (macOS + iOS-Simulator Store **und** Private + Release-Binary-Check) auf PRs und Push auf `master`
- `codeql.yml`: CodeQL auf Push nach `master` und wöchentlichem Schedule (nicht auf jedem PR — der instrumentierte Swift-Build kostet ~30 min macOS)
- `gitleaks.yml`: Secret-Scan auf PR, Push und täglichem Schedule
- `actionlint.yml`: Workflow-Lint bei Änderungen unter `.github/workflows/`
- `scorecard.yml`: OpenSSF Scorecard auf Push nach `master`, Branch-Protection-Events und wöchentlichem Schedule
- `release.yml`: Tag-Releases (`v*`) inkl. optionalem Signing/Notarize und Einbettung von `REISEN_GITHUB_ISSUES_TOKEN_BASE64`
- `versions-update.yml`: Wöchentliches Update von actionlint-URL, Xcode-Pin, Swift-Tools-Version und Gitleaks-Version

## Pin-Updates (SSOT-Trennung)

| Was | Werkzeug |
|-----|----------|
| GitHub-Action-SHAs (`uses: …@<sha> # vX.Y.Z`) | [Dependabot](../../.github/dependabot.yml) (`github-actions`, wöchentlich) |
| actionlint-Installer-URL, `xcode-version: latest`, `swift-tools-version`, `GITLEAKS_VERSION` | [`Scripts/update-versions.sh`](../../Scripts/update-versions.sh) via `versions-update.yml` |

Dependabot-PRs laufen durch die echte CI. Der Versions-Workflow nutzt `--verify` nur, wenn Dateien geändert wurden.

## Lokale CI-Parität

| Schritt | Befehl |
|---------|--------|
| Swift-Tests (wie CI Job „Test“) | `bash ./Scripts/ci-test.sh` |
| + iOS Release-Binary-Isolation | `bash ./Scripts/ci-test.sh --with-ios-release-check` |
| iOS-Simulator (Store + Private) | `IOS_SCHEME=all bash ./Scripts/ios-test.sh` |

Vollständige GitHub-CI: zusätzlich `ios-test.sh` und `ios-build-release-check.sh` als eigene Steps in [`ci.yml`](../../.github/workflows/ci.yml).

## SwiftPM-Cache (CI + CodeQL)

Cache-Key (ohne Commit-SHA, damit Einträge wiederverwendet werden):

```yaml
key: ${{ runner.os }}-spm-${{ hashFiles('Package.swift', '**/Package.resolved') }}
restore-keys: |
  ${{ runner.os }}-spm-
```

CodeQL cached nur SPM-/Module-Caches (nicht `.build`): der Tracer braucht ohnehin einen instrumentierten Compile. Der Build läuft über [`Scripts/ci-build.sh`](../../Scripts/ci-build.sh) `--arch arm64` (keine Test-Targets, eine Architektur).

## Branch Protection

- Pflicht-Check für Merges: GitHub-Actions-Check **`CI`** aus [`ci.yml`](../../.github/workflows/ci.yml) (Check-Run, kein separater Legacy-Commit-Status)
- CodeQL läuft nicht auf PRs; Scorecard/Gitleaks optional, nicht als Pflicht

## Dependency Review (Follow-up)

Der Workflow `dependency-review.yml` ist entfernt, solange keine [`Package.resolved`](../../Package.resolved) im Repo liegt. Nach Commit des Lockfiles kann der Workflow wieder ergänzt werden.

## Release-Environment (optional)

Für manuelle Freigabe von Tag-Releases kann in GitHub ein Environment `release` mit Required Reviewers angelegt werden — aktuell nicht im Workflow verdrahtet (Repo-Setting nötig).

## Apple Signing / Notarization

Team-ID, Bundle-IDs, lokales Setup und Release-Secrets: [`apple-signing.md`](apple-signing.md). Einmalig: `bash ./Scripts/setup-apple-developer.sh`.

| Variante | Doku |
|----------|------|
| App Store (Store-iOS) | [`app-store-connect.md`](app-store-connect.md) |
| Private-iOS (Ad Hoc / Internal TestFlight) | [`ios-private-distribution.md`](ios-private-distribution.md) |
| macOS Developer ID | [`apple-signing.md`](apple-signing.md) (Release-Section) |

In-App öffentliche GitHub-Issues: [`github-issues-token.md`](github-issues-token.md) (optional, nur Debug/lokale Builds). App-Store-iOS ohne eingebettetes Token: [`app-store-connect.md`](app-store-connect.md).

## AI-Assistenz & kostenlose PR-Reviewer (Open Source / public)

Dieses Repo unterstützt ausdrücklich den Einsatz von AI/LLMs als Hilfswerkzeug. Für die Regeln gilt **`AI_POLICY.md`** und der Rahmen aus **`AGENTS.md`** (Human-in-the-loop).

Wenn du kostenlose (oder Free-Tier) PR-Reviewer für öffentliche Repos nutzt, gelten zusätzlich diese Leitplanken:

- AI-Ausgaben (Reviews/Kommentare) sind Hinweise; der Beitragende muss sie verstehen und selbst verifizieren.
- Keine Secrets in Logs oder Kommentaren.
- Keine autonomen Änderungen ohne menschliche Prüfung.

### Beispiel: CodeRabbit (public kostenlos)

CodeRabbit bietet für **öffentliche Repos** kostenlosen PR-Code-Review über eine GitHub App. Falls du dieses Setup nutzt:

1. Installiere die CodeRabbit GitHub App im Repo.
2. Aktiviere Review-Modi wie gewünscht (z. B. Code-Review & Security-Review).
3. Halte dich an `.github/copilot-instructions.md`/`AI_POLICY.md` als gemeinsame Stil-/Sicherheitsreferenz für Review-Kommentare.

Hinweis: Die relevanten CodeRabbit-Defaults sind zusätzlich als Versions-vor-Config im Repo unter `.coderabbit.yaml` hinterlegt (u. a. „Auto-Review“ und „OpenGrep“ als Security-Tool).

### Optional: GitHub Copilot Code Review

Wenn du GitHub Copilot (Pro/Org/Business, je nach Verfügbarkeit) nutzt, kannst du Copilot Code Review im Repo-Settings aktivieren (z. B. „automatic reviews“, sofern angeboten).

Wichtig:
- Copilot-Reviews sind Hinweise, die vom Beitragenden verstanden und verifiziert werden müssen (siehe `AI_POLICY.md`).
- Für die gewünschte Review-Qualität nutze `.github/copilot-instructions.md` als gemeinsame Referenz im Repo.
