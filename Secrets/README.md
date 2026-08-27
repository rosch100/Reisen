# Lokale Secrets (nicht committen)

Dieses Verzeichnis ist in `.gitignore` (außer `*.example`).

- `github-issues.token` — Issues-only-PAT für lokale Produkt-Builds und macOS-Releases
- Siehe `docs/ci/github-issues-token.md`

**App-Store-iOS-Builds** betten das Token **nicht** ein (`Scripts/ios-archive-appstore.sh` setzt `REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true`).
