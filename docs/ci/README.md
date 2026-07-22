# CI für Reisen

Dieser Ordner dokumentiert die CI/CD-Infrastruktur im Repo.

## Verfügbare Workflows

- `ci.yml`: Build+Test auf PRs und Push auf `master`
- `codeql.yml`: CodeQL (Scheduled + PR)
- `scorecard.yml`: OpenSSF Scorecard
- `release.yml`: Tag-Releases (`v*`) inkl. optionalem Signing/Notarize

## Apple Signing / Notarization

Siehe [`apple-signing.md`](apple-signing.md).

## Branch Protection (Empfehlung)

- Pflicht-Check für Merges: Workflow `CI` aus [`ci.yml`](../../.github/workflows/ci.yml)
- Optional: CodeQL/Scorecard nicht als Pflicht setzen (sie laufen als Security-Workflows und können bei Toolchain-Mismatches temporär fehlschlagen)

## AI-Assistenz & kostenlose PR-Reviewer (Open Source / public)

Dieses Repo unterstützt ausdrücklich den Einsatz von AI/LLMs als Hilfswerkzeug. Für die Regeln gilt **`AI_POLICY.md`** und der Rahmen aus **`AGENTS.md`** (Human-in-the-loop).

Wenn du kostenlose (oder Free-Tier) PR-Reviewer für öffentliche Repos nutzt, gelten zusätzlich diese Leitplanken:

- AI-Ausgaben (Reviews/Kommentare) sind Hinweise; der Beitragende muss sie verstehen und selbst verifizieren.
- Keine Secrets in Logs oder Kommentaren.
- Keine autonomen Änderungen ohne menschliche Prüfung.

### Beispiel: CodeRabbit (public kostenlos)

CodeRabbit bietet für **öffentliche Repos** kostenlosen PR-Code-Review über eine GitHub App. Falls du dieses Setup nutzt:

1. Installiere die CodeRabbit GitHub App im Repo `rosch100/Reisen`.
2. Aktiviere Review-Modi wie gewünscht (z. B. Code-Review & Security-Review).
3. Halte dich an `.github/copilot-instructions.md`/`AI_POLICY.md` als gemeinsame Stil-/Sicherheitsreferenz für Review-Kommentare.

Hinweis: Die relevanten CodeRabbit-Defaults sind zusätzlich als Versions-vor-Config im Repo unter `.coderabbit.yaml` hinterlegt (u. a. „Auto-Review“ und „OpenGrep“ als Security-Tool).

### Optional: GitHub Copilot Code Review

Wenn du GitHub Copilot (Pro/Org/Business, je nach Verfügbarkeit) nutzt, kannst du Copilot Code Review im Repo-Settings aktivieren (z. B. „automatic reviews“, sofern angeboten).

Wichtig:
- Copilot-Reviews sind Hinweise, die vom Beitragenden verstanden und verifiziert werden müssen (siehe `AI_POLICY.md`).
- Für die gewünschte Review-Qualität nutze `.github/copilot-instructions.md` als gemeinsame Referenz im Repo.

