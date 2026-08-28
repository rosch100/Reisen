# Issue-Dev (Grok Bot) — Reisen

Eingehende Issues (`kind/error`, `kind/feature`, `kind/feedback`) können nach **Maintainer-Freigabe** vom Grok-Bot-Team mit `/bugfix` bzw. `/feature-dev` bis zum **PR** entwickelt werden. **Kein Auto-Merge.**

Pipeline-SSOT liegt in **Altanis/CI** (`config/issue-dev/`, `docs/issue-dev-grok-bot.md`). Dieses Repo ist der erste GitHub-Consumer.

## Labels

Ensure legt an bzw. ergänzt (idempotent):

- `issue-dev/await-confirm`, `issue-dev/approved`, `issue-dev/blocked`, `issue-dev/skip`
- `kind/feature` (neu); `kind/error`, `kind/feedback`, `source/*` nur wenn fehlend

```bash
# Vom CI-Checkout, mit Token:
pwsh -NoProfile -File scripts/ci/Invoke-IssueDevEnsureConfig.ps1 -OnlyRepo rosch100/Reisen
```

## Freigabe

1. Bot postet Kurzfassung + Status `await-human-confirm` (Marker `<!-- issue-dev -->`).
2. Maintainer: `/approve` (nach `/adjust` erneut `/approve`), oder Label `issue-dev/approved`.
3. Delivery öffnet PR; Mensch reviewed und merged.

## Wake

[`.github/workflows/issue-dev-wake.yml`](../../.github/workflows/issue-dev-wake.yml) + [`Scripts/issue-dev-forward.sh`](../../Scripts/issue-dev-forward.sh).

Secrets (Werte nicht im Git):

- `ISSUE_DEV_WEBHOOK_SECRET` (HMAC, optional wenn nur Actions-Pfad)
- `ISSUE_DEV_GROK_WEBHOOK_URL` / `ISSUE_DEV_GROK_WEBHOOK_KEY` (Desktop-Routine-Panel)

Gmail-Ingress legt Issues an → GitHub `issues: opened` triggert denselben Wake (kein IMAP im Bot).

## Feature-Template

[`.github/ISSUE_TEMPLATE/feature.yml`](../../.github/ISSUE_TEMPLATE/feature.yml) setzt `kind/feature`.
