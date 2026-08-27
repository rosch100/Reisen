# Lokale Secrets (nicht committen)

Dieses Verzeichnis ist in `.gitignore` (außer `*.example`).

- `github-issues.token` — Issues-only-PAT für lokale Produkt-Builds und App-Store-Archive
- Siehe `docs/ci/github-issues-token.md`

**App-Store-iOS-Builds** betten das Token ein (`Scripts/ios-archive-appstore.sh`, Pflicht).
