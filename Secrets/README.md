# Lokale Secrets (nicht committen)

Dieses Verzeichnis ist in `.gitignore` (außer `*.example`).

- `github-issues.token` — Issues-only-PAT für lokale Produkt-Builds, macOS-Releases und iOS Store-/Ad-hoc-Archives
- Siehe `docs/ci/github-issues-token.md`

**iOS-Produkt-Archives** betten das Token ein (`Scripts/ios-archive-appstore.sh` / `ios-archive-adhoc.sh` setzen `REISEN_REQUIRE_GITHUB_ISSUE_TOKEN=true`).

Gmail-Feedback-Ingress: OAuth-Client und Refresh-Token nur als GitHub-Actions-Secrets (`REISEN_GMAIL_OAUTH_*`) — siehe `docs/ci/gmail-feedback-ingress.md`. Nicht in diesem Verzeichnis ablegen.

App Store Check (manuelles Store-IPA-Archive): GitHub-Secrets `REISEN_GITHUB_ISSUES_TOKEN_BASE64`, `APP_STORE_CONNECT_API_KEY_*` und `APPLE_TEAM_ID` — siehe `docs/ci/app-store-check.md`. Nicht in diesem Verzeichnis ablegen.
