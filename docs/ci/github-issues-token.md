# In-App GitHub-Issues Token

**App-Store-iOS-Builds** (`Scripts/ios-archive-appstore.sh`) betten **kein** Token ein — Feedback öffnet ein vorausgefülltes GitHub-Issue in Safari.

Optional für **lokale Debug-Builds** (`ios-run.sh` setzt `REISEN_EMBED_GITHUB_ISSUE_TOKEN=true`) und **macOS-Tag-Releases** (`release.yml` → `Scripts/build-app.sh --configuration release`) kann ein fine-grained PAT als XOR-Payload eingebettet werden. Das Token steht **nicht** im Git.

Die Compile-Quelle `GitHubIssueToken.generated.swift` ist gitignored. Versioniert ist nur `GitHubIssueToken.generated.swift.stub` (leere `bytes`/`key`). `Scripts/embed-github-issue-token.sh` schreibt vor dem Compile die Generated-Datei: ohne Token aus dem Stub, mit Token als XOR.

## Secret anlegen

1. Fine-grained PAT nur für `rosch100/Reisen`, Permission **Issues: Read and write** (ggf. Repository-Allowlist).
2. Base64 ohne Zeilenumbruch:

```bash
printf '%s' "$PAT" | base64 | tr -d '\n'
```

3. GitHub → Settings → Secrets and variables → Actions → `REISEN_GITHUB_ISSUES_TOKEN_BASE64`.

`GITHUB_TOKEN` des Workflows ist ungeeignet (läuft mit dem Job ab).

## Lokaler App-Build

Persistenz auf diesem Mac (nicht im Git):

1. PAT in die Zwischenablage, dann `bash ./Scripts/store-github-issue-token.sh`
2. Ablage: `Secrets/github-issues.token` (chmod 600), `Secrets/github-issues.env` (`export REISEN_GITHUB_ISSUES_TOKEN=…`), Keychain-Service `reisen.github-issues-token`

`Scripts/embed-github-issue-token.sh` liest in dieser Reihenfolge: Env → lokale Token-Datei → Keychain.

Optional in `~/.zshrc` (nur der Source-Pfad, nicht das PAT):

```bash
# Reisen GitHub Issues token (local)
[ -f "$HOME/Entwicklung/Reisen/Secrets/github-issues.env" ] && . "$HOME/Entwicklung/Reisen/Secrets/github-issues.env"
```

Ohne Secret bleibt die Payload leer (Kopie des Stubs); die App baut, das Melden schlägt explizit fehl. Tag-Releases ohne Secret brechen ab (`REISEN_REQUIRE_GITHUB_ISSUE_TOKEN=true`).

Tests (`Scripts/ci-test.sh`, `Scripts/ci-build.sh`, `ios-test.sh`) setzen `REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true` und betten das Token **nicht** ein. Produkt-iOS-Läufe setzen `REISEN_EMBED_GITHUB_ISSUE_TOKEN=true` vor `generate-ios-project.sh`.

`ci-test.sh` prüft, dass der Stub leere `bytes`/`key`-Arrays hat und dass `GitHubIssueToken.generated.swift` nicht git-tracked ist.

## Akzeptiertes Restrisiko

XOR ist Obfuskation, kein Schutz: das PAT ist aus einem Release-Binary rekonstruierbar. `maxCreatesPerHour` gilt nur in der App und ist mit extrahiertem Token umgehbar.

Harte Grenze ist GitHub-seitig: fine-grained PAT mit **Issues: Read and write**, nur Repository `rosch100/Reisen`. Die App-Limits sind eine zusätzliche Dämpfung, keine Sicherheitsgrenze.
