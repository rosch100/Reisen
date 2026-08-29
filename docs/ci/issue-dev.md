# Issue-Dev (Grok Bot) — Reisen

Bei **Bugs** (Label `kind/error`) startet das Grok-Bot-Team **ohne `/approve`**: zuerst Diagnoser (P0–P1), nach P1-Judge Bugfix-Delivery bis zum **PR**. Kommentar `/bugfix` ist kein Gate. **Feature-Requests** (`kind/feature`) brauchen erst Maintainer-`/approve`. Feedback wird triagiert. **Kein Auto-Merge.**

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
| Bug / Fehler (`kind/error`) | Kein `/approve`. Auto-Start nur über das **Label**, nicht durch Kommentar `/bugfix`. Dispatcher: Diagnoser dann P1-Judge, danach Bugfix-Delivery (`in-progress`). |
| Feature-Request (`kind/feature`) | 1. Bot postet Kurzfassung + Status `await-human-confirm` (Marker `<!-- issue-dev -->`). 2. Maintainer: `/approve` (nach `/adjust` erneut `/approve`), oder Label `issue-dev/approved`. 3. Feature-Delivery. |
| Feedback (`kind/feedback`) | Triage; Delivery erst nach Klassifizierung. |

Delivery öffnet PR; Mensch reviewed und merged.

## Wake

[`.github/workflows/issue-dev-wake.yml`](../../.github/workflows/issue-dev-wake.yml) + [`Scripts/issue-dev-forward.sh`](../../Scripts/issue-dev-forward.sh).

Secrets (Werte nicht im Git):

- `ISSUE_DEV_WEBHOOK_SECRET` (HMAC, optional wenn nur Actions-Pfad)
- `ISSUE_DEV_GROK_WEBHOOK_URL` / `ISSUE_DEV_GROK_WEBHOOK_KEY` (Desktop-Routine-Panel)

Gmail-Ingress legt Issues an → GitHub `issues: opened` triggert denselben Wake. **Kein IMAP.** Der Diagnoser lädt Anhänge mit `Invoke-IssueDevExpandAttachments.ps1` über die Gmail-API nur, wenn der Issue-Body `<!-- issue-dev-gmail-id: … -->` enthält **und** das Issue vom Ingress stammt: Autor `github-actions[bot]` und Label `source/email` (Ingress setzt zusätzlich `kind/feedback`; nach Reklassifizierung zu `kind/error` darf `kind/feedback` fehlen). Ein von Nutzer:innen angelegtes `kind/error` mit kopiertem Marker löst **keinen** Gmail-Request aus. Marker: Gmail-Message-Id, nicht RFC-Message-ID; **letzte** HTML-Kommentar-Instanz, nicht Kommentare, auch nicht bei leerem Body. Ingress entfernt HTML-Kommentare aus Von/Datum/Betreff/Text/Dateinamen.

Auf dem **Grok-Bot-Rechner** dieselben OAuth-Werte wie der Ingress, plus erwartete Mailbox:

| Env | Inhalt |
|-----|--------|
| `ISSUE_DEV_GMAIL_OAUTH_CLIENT_ID` | OAuth-Client-ID (gleiche Werte wie Ingress-Secret `REISEN_GMAIL_OAUTH_CLIENT_ID`) |
| `ISSUE_DEV_GMAIL_OAUTH_CLIENT_SECRET` | OAuth-Client-Secret |
| `ISSUE_DEV_GMAIL_OAUTH_REFRESH_TOKEN` | Refresh-Token |
| `ISSUE_DEV_GMAIL_EXPECTED_ADDRESS` | `reisenapp100@gmail.com` |

Ohne diese Env bei gesetzter Id bricht P1 mit klarem Fehler ab (kein stilles `named_only_gap`). Die Mail bleibt nach dem Ingress in Gmail (gelesen); der Bot adressiert sie über die Id. Der Grok-Bot-Host liest dasselbe Postfach über den Gmail-Adapter.

Nach PR oder BLOCKED: `Invoke-IssueDevCleanupAttachments.ps1` (gleiches Host/Owner/Repo/IssueNumber, Default-WorkDir). Keine Temp-Dumps liegen lassen.

## Fehleranhänge (P1)

Bei `kind/error` wertet der Diagnoser Anhänge aus, **bevor** die Hypothese steht: GitHub-`user-attachments`-URLs und Gmail-MIME (Marker `issue-dev-gmail-id` plus Ingress-Provenienz). Archive (`.zip`, `.ipa`, `.7z`, EurekaLog `.elf`, `.cpgz`, `.tar.gz`) entpacken, Logs/Crash lesen. Skript-SSOT: Altanis/CI `Invoke-IssueDevExpandAttachments.ps1`.

## Fehleranhänge (P1)

GitHub-Issues aus der App und dem Gmail-Ingress haben **keine Dateianhänge** (Issues-API). Diagnose steht im Issue-Text (Meldung, Gerätefelder, technische Details, Sync-Protokoll-Auszug, geschwärzte inlined Textanhänge). Binäre Dateien (Screenshots, Archive) kommen per E-Mail an `reisenapp100@gmail.com` und bleiben in der Mailbox — nur Dateinamen in der Gmail-Tabelle `| Anhänge | … |` sind **keine** ausgewerteten Bytes.

Wenn der Diagnoser trotzdem lokale Anhänge hat (Maintainer-Upload, WorkDir): vor der Hypothese Archive (`.zip`, `.ipa`, `.7z`, EurekaLog `.elf`, `.cpgz`, `.tar.gz`) entpacken, Logs/Crash lesen, Screenshots nur wenn der Text nicht reicht. Skript-SSOT: Altanis/CI `Invoke-IssueDevExpandAttachments.ps1`. Der Grok-Bot läuft auf **Linux** und braucht `7z` (`p7zip-full`) sowie `gzip`+`cpio` für `.cpgz` (Check: `Invoke-IssueDevAssertHostTools.ps1`). 7z- und EurekaLog-Archive mit dem bekannten Bugreport-Passwort (nicht loggen).

## Feature-Template

[`.github/ISSUE_TEMPLATE/feature.yml`](../../.github/ISSUE_TEMPLATE/feature.yml) setzt `kind/feature`. Chooser und weitere Formulare: [`.github/ISSUE_TEMPLATE/`](../../.github/ISSUE_TEMPLATE/), Vertrag mit In-App-Meldung: [github-issues-token.md](github-issues-token.md) (Abschnitt Issue-Formulare und Chooser).
