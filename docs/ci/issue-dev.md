# Issue-Dev (Grok Bot) — Reisen

Bei **Bugs** (Label `kind/error`) startet das Grok-Bot-Team **sofort** bis zum **PR**. Kommentar `/bugfix` ist kein Gate. **Feature-Requests** (`kind/feature`) brauchen erst Maintainer-`/approve`. Feedback wird triagiert. **Kein Auto-Merge.**

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

| Art | Ablauf |
|-----|--------|
| Bug / Fehler (`kind/error`) | Kein `/approve`. Auto-Start nur über das **Label**, nicht durch Kommentar `/bugfix`. Dispatcher startet Bugfix-Delivery sofort (`in-progress`). |
| Feature-Request (`kind/feature`) | 1. Bot postet Kurzfassung + Status `await-human-confirm` (Marker `<!-- issue-dev -->`). 2. Maintainer: `/approve` (nach `/adjust` erneut `/approve`), oder Label `issue-dev/approved`. 3. Feature-Delivery. |
| Feedback (`kind/feedback`) | Triage; Delivery erst nach Klassifizierung. |

Delivery öffnet PR; Mensch reviewed und merged.

## Wake

[`.github/workflows/issue-dev-wake.yml`](../../.github/workflows/issue-dev-wake.yml) + [`Scripts/issue-dev-forward.sh`](../../Scripts/issue-dev-forward.sh).

Secrets (Werte nicht im Git):

- `ISSUE_DEV_WEBHOOK_SECRET` (HMAC, optional wenn nur Actions-Pfad)
- `ISSUE_DEV_GROK_WEBHOOK_URL` / `ISSUE_DEV_GROK_WEBHOOK_KEY` (Desktop-Routine-Panel)

Gmail-Ingress legt Issues an → GitHub `issues: opened` triggert denselben Wake (kein IMAP im Bot).

## Feature-Template

[`.github/ISSUE_TEMPLATE/feature.yml`](../../.github/ISSUE_TEMPLATE/feature.yml) setzt `kind/feature`.
