# In-App GitHub-Issues Token

**App-Store-iOS-Builds** (`Scripts/ios-archive-appstore.sh`) betten **kein** Token ein — Feedback öffnet ein vorausgefülltes GitHub-Issue in Safari. Ein optional in den Einstellungen hinterlegter GitHub-Benutzername dient nur der **Zuordnung** im Issue-Text (Attribution), nicht dem Wechsel des Meldewegs.

macOS-Tag-Releases und lokale Debug-Läufe können ein fine-grained PAT als XOR-Payload einbetten; dann legt die App Issues ohne GitHub-Konto des Nutzers an. Das Token steht **nicht** im Git.

Die Compile-Quelle `GitHubIssueToken.generated.swift` ist gitignored. Versioniert ist nur `GitHubIssueToken.generated.swift.stub` (leere `bytes`/`key`). `Scripts/embed-github-issue-token.sh` schreibt vor dem Compile die Generated-Datei: ohne Token aus dem Stub, mit Token als XOR.

## Secret anlegen

1. Fine-grained PAT nur für `rosch100/Reisen`, Permission **Issues: Read and write** (ggf. Repository-Allowlist).
2. Base64 ohne Zeilenumbruch:

```bash
printf '%s' "$PAT" | base64 | tr -d '\n'
```

3. GitHub → Settings → Secrets and variables → Actions → `REISEN_GITHUB_ISSUES_TOKEN_BASE64`.

`GITHUB_TOKEN` des Workflows ist ungeeignet (läuft mit dem Job ab).

## Wo das Token eingebettet wird

| Pfad | Token einbetten? |
|------|------------------|
| `Scripts/build-app.sh` (macOS `.app`) | Ja. Release-CI: Secret Pflicht (`REISEN_REQUIRE_GITHUB_ISSUE_TOKEN`). |
| `Scripts/generate-ios-project.sh` | Ja, sofern nicht `REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true`. |
| `Scripts/ios-run.sh` / `ios-run-device.sh` | Ja (lokales Token aus Env, `Secrets/github-issues.token` oder Keychain). |
| `Scripts/ios-archive-appstore.sh` | Nein (`REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true`) — Store-Binary ohne PAT. |
| `Scripts/ios-archive-adhoc.sh` | Nein (`REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true`). |
| `Scripts/ci-test.sh` / `ci-build.sh` / `ios-test.sh` | Nein (`REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true`). |

Ohne Token bleibt die Payload leer; die App baut, API-Meldung schlägt explizit fehl. Die UI kann ein vorausgefülltes Issue in Safari öffnen (GitHub-Konto des Nutzers).

## Lokaler App-Build

Persistenz auf diesem Mac (nicht im Git):

1. PAT in die Zwischenablage, dann `bash ./Scripts/store-github-issue-token.sh`
2. Ablage: `Secrets/github-issues.token` (chmod 600), `Secrets/github-issues.env` (`export REISEN_GITHUB_ISSUES_TOKEN=…`), Keychain-Service `reisen.github-issues-token`

`Scripts/embed-github-issue-token.sh` liest in dieser Reihenfolge: Env → lokale Token-Datei → Keychain → `REISEN_GITHUB_ISSUES_TOKEN_BASE64`.

Optional in `~/.zshrc` (nur der Source-Pfad, nicht das PAT):

```bash
# Reisen GitHub Issues token (local)
[ -f "$HOME/Entwicklung/Reisen/Secrets/github-issues.env" ] && . "$HOME/Entwicklung/Reisen/Secrets/github-issues.env"
```

Tag-Releases ohne Secret brechen ab (`REISEN_REQUIRE_GITHUB_ISSUE_TOKEN=true`). App-Store-Archive betten das Token nicht ein.

`ci-test.sh` prüft, dass der Stub leere `bytes`/`key`-Arrays hat, dass `GitHubIssueToken.generated.swift` nicht git-tracked ist, und dass `ios-archive-appstore.sh` das Token per `EMPTY=true` unterdrückt.

## Akzeptiertes Restrisiko

XOR ist Obfuskation, kein Schutz: das PAT ist aus einem Release-Binary rekonstruierbar. `maxCreatesPerHour` gilt nur in der App und ist mit extrahiertem Token umgehbar.

Harte Grenze ist GitHub-seitig: fine-grained PAT mit **Issues: Read and write**, nur Repository `rosch100/Reisen`. Die App-Limits sind eine zusätzliche Dämpfung, keine Sicherheitsgrenze.

## Issue-Labels

Die öffentlichen Issue-Formulare setzen nur `kind/error` bzw. `kind/feedback`. `source/in-app` setzt die App beim Anlegen bzw. in der vorausgefüllten URL — nicht das Web-Formular, damit Browser-Meldungen nicht fälschlich als In-App gelten. Die Labels müssen am Repo existieren — die Issues-API antwortet sonst mit 422.
