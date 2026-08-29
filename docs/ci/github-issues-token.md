# In-App GitHub-Issues Token

**Produkt-iOS-Archives** (`Scripts/ios-archive-appstore.sh`, `Scripts/ios-archive-adhoc.sh`) betten dasselbe Issues-only-PAT ein wie macOS-Tag-Releases. Feedback in der App legt ein öffentliches Issue an, ohne GitHub-Konto des Nutzers. Ein optional in den Einstellungen hinterlegter GitHub-Benutzername dient nur der **Zuordnung** im Issue-Text (Attribution).

Zusätzlich: E-Mail an `reisenapp100@gmail.com` (`GitHubRepository.feedbackEmail`) wird per [gmail-feedback-ingress.md](gmail-feedback-ingress.md) zu einem Issue (`kind/feedback`, `source/email`).

Das Token steht **nicht** im Git.

Die Compile-Quelle `GitHubIssueToken.generated.swift` ist gitignored. Versioniert ist nur `GitHubIssueToken.generated.swift.stub` (leere `bytes`/`key`). `Scripts/embed-github-issue-token.sh` schreibt vor dem Compile die Generated-Datei: ohne Token aus dem Stub, mit Token als XOR.

## Secret anlegen

1. Fine-grained PAT nur für `rosch100/Reisen`, Permission **Issues: Read and write** (ggf. Repository-Allowlist).
2. Base64 ohne Zeilenumbruch:

```bash
printf '%s' "$PAT" | base64 | tr -d '\n'
```

3. GitHub → Settings → Secrets and variables → Actions → `REISEN_GITHUB_ISSUES_TOKEN_BASE64`.

`GITHUB_TOKEN` des Workflows ist ungeeignet für das **App-Binary** (läuft mit dem Job ab). Der Gmail-Ingress nutzt `GITHUB_TOKEN` nur im Action-Lauf (`github-actions[bot]`).

## Wo das Token eingebettet wird

| Pfad | Token einbetten? |
|------|------------------|
| `Scripts/build-app.sh` (macOS `.app`) | Ja. Release-CI: Secret Pflicht (`REISEN_REQUIRE_GITHUB_ISSUE_TOKEN`). |
| `Scripts/generate-ios-project.sh` | Ja, sofern nicht `REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true`. |
| `Scripts/ios-run.sh` / `ios-run-device.sh` | Ja (lokales Token aus Env, `Secrets/github-issues.token` oder Keychain). |
| `Scripts/ios-archive-appstore.sh` | Ja (`REISEN_EMBED_GITHUB_ISSUE_TOKEN=true`, `REISEN_REQUIRE_GITHUB_ISSUE_TOKEN=true`). Workflow **App Store Check** reicht `REISEN_GITHUB_ISSUES_TOKEN_BASE64` durch; das IPA wird nicht als Artifact hochgeladen. |
| `Scripts/ios-archive-adhoc.sh` | Ja (wie Store). |
| `Scripts/ci-test.sh` / `ci-build.sh` / `ios-test.sh` | Nein (`REISEN_GITHUB_ISSUE_TOKEN_EMPTY=true`). |

Bei Builds ohne Token-Pflicht (CI, Tests) bleibt die Payload leer; die App baut, die API-Meldung schlägt explizit fehl. Store- und Ad-hoc-Archive sowie macOS-Release-CI brechen ohne Token vor dem Compile ab. Die UI kann ein vorausgefülltes Issue in Safari öffnen (GitHub-Konto des Nutzers) oder `mailto:reisenapp100@gmail.com`.

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

Tag-Releases und Store-/Ad-hoc-Archives ohne Secret brechen ab (`REISEN_REQUIRE_GITHUB_ISSUE_TOKEN=true`).

`ci-test.sh` prüft, dass der Stub leere `bytes`/`key`-Arrays hat, dass `GitHubIssueToken.generated.swift` nicht git-tracked ist, und dass die iOS-Archive-Scripts das Token **einbetten** (kein `EMPTY=true`).

## Akzeptiertes Restrisiko

XOR ist Obfuskation, kein Schutz: das PAT ist aus einem Release-Binary rekonstruierbar. `maxCreatesPerHour` gilt nur in der App und ist mit extrahiertem Token umgehbar.

Harte Grenze ist GitHub-seitig: fine-grained PAT mit **Issues: Read and write**, nur Repository `rosch100/Reisen`. Die App-Limits sind eine zusätzliche Dämpfung, keine Sicherheitsgrenze.

## Issue-Labels

Die öffentlichen Issue-Formulare setzen nur `kind/error` bzw. `kind/feedback`. `source/in-app` setzt die App beim Anlegen bzw. in der vorausgefüllten URL — nicht das Web-Formular, damit Browser-Meldungen nicht fälschlich als In-App gelten. Mail-Ingress setzt `kind/feedback` und `source/email`. Die Labels müssen am Repo existieren. Fehlen sie oder darf der Aufrufer keine Labels setzen, kann GitHub das Issue trotzdem anlegen — dann ohne diese Labels. HTTP 422 ist eine allgemeine Validierungs- oder Spam-Antwort, kein fester Fehlcode für fehlende Labels.

Paste-Import kann nach Bestätigung ein Issue `kind/feature` anlegen. Das Originaldokument hängt die App nicht an das Issue; es geht per E-Mail an `reisenapp100@gmail.com`. Dafür reicht dasselbe Issues-PAT; kein Contents-Recht und kein zweites Repository.
