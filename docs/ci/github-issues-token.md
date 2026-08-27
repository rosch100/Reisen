# In-App GitHub-Issues Token

Jede laufende Produkt-App (iOS und macOS, Debug und Release) kann **ohne GitHub-Konto des Nutzers** ein öffentliches Issue anlegen, sobald ein Token eingebettet ist. Ein optional in den Einstellungen hinterlegter GitHub-Benutzername dient nur der **Zuordnung** im Issue-Text (Attribution), nicht dem Wechsel auf Safari/GitHub-Login. Ohne eingebettetes Token öffnet die App ein vorausgefülltes Issue im Browser (dafür braucht der Nutzer ein GitHub-Konto).

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
| `Scripts/ios-archive-appstore.sh` | Ja, Pflicht — sonst bricht das Archive ab (ausgelieferte App ohne Kanal). |
| `Scripts/ci-test.sh` / `ci-build.sh` / `ios-test.sh` | Nein (`REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true`). |

Ohne Token in Debug-Builds bleibt die Payload leer; die App baut, das Melden über die API schlägt explizit fehl. Zusätzlich kann die UI ein vorausgefülltes Issue in Safari öffnen (dafür braucht der Entwickler ein GitHub-Konto). Produkt-Builds dürfen diesen Fallback nicht als einzigen Kanal haben.

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

Tag-Releases und App-Store-Archive ohne Secret brechen ab (`REISEN_REQUIRE_GITHUB_ISSUE_TOKEN=true`).

`ci-test.sh` prüft, dass der Stub leere `bytes`/`key`-Arrays hat, dass `GitHubIssueToken.generated.swift` nicht git-tracked ist, und dass `ios-archive-appstore.sh` das Token nicht per `EMPTY=true` unterdrückt.

## Akzeptiertes Restrisiko

XOR ist Obfuskation, kein Schutz: das PAT ist aus einem Release-Binary rekonstruierbar. `maxCreatesPerHour` gilt nur in der App und ist mit extrahiertem Token umgehbar.

Harte Grenze ist GitHub-seitig: fine-grained PAT mit **Issues: Read and write**, nur Repository `rosch100/Reisen`. Die App-Limits sind eine zusätzliche Dämpfung, keine Sicherheitsgrenze.
