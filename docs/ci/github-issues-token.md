# In-App GitHub-Issues Token

**Produkt-iOS-Archives** (`Scripts/ios-archive-appstore.sh`, `Scripts/ios-archive-adhoc.sh`, `Scripts/ios-archive-private-testflight.sh`) betten dasselbe Issues-only-PAT ein wie macOS-Tag-Releases. Feedback in der App legt ein öffentliches Issue an, ohne GitHub-Konto des Nutzers. Ein optional in den Einstellungen hinterlegter GitHub-Benutzername dient nur der **Zuordnung** im Issue-Text (Attribution).

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
| `Scripts/ios-archive-private-testflight.sh` | Ja (wie Store; nur Internal TestFlight, kein Store-Listing). |
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

## GitHub-REST-Vertrag

SSOT der Limits und Header: `GitHubRepository` (`restAPIVersion`, `restUserAgent`, `issueTitleMaxLength`, `issueBodyMaxLength`). Offizielle Referenz: [REST API endpoints for issues](https://docs.github.com/en/rest/issues/issues?apiVersion=2022-11-28), [Getting started](https://docs.github.com/en/rest/using-the-rest-api/getting-started-with-the-rest-api) (`User-Agent` Pflicht), [Issue comments](https://docs.github.com/en/rest/issues/comments), [Search issues](https://docs.github.com/en/rest/search/search#search-issues-and-pull-requests).

| Vorgabe | Reisen |
| --- | --- |
| `POST /repos/{owner}/{repo}/issues` | App-Token und Gmail-Ingress |
| `POST .../issues/{n}/comments` | Duplikat-Fingerprint |
| `GET /search/issues` mit `is:issue` | offene Fingerprint-Suche; Suchbegriff ≤ 256 Zeichen |
| `Accept: application/vnd.github+json` | ja |
| `Authorization: Bearer` | ja |
| `X-GitHub-Api-Version: 2022-11-28` | ja |
| `User-Agent` | App `Reisen`; Ingress `reisen-gmail-feedback-ingress` |
| Titel max. 256 Zeichen | gekürzt |
| Body/Kommentar max. 65536 Zeichen | gekürzt; kein Datei-Upload in der Issues-API |
| Labels nur mit Push-Recht, sonst still verworfen | siehe Abschnitt Issue-Labels |
| New-Issue-URL `template`, `title`, `labels`, Feld-`id` | Safari-Pfad ohne Token |

## Issue-Labels

Die öffentlichen Issue-Formulare setzen nur `kind/error`, `kind/feedback` bzw. `kind/feature`. `source/in-app` setzt die App beim Anlegen bzw. in der vorausgefüllten URL — nicht das Web-Formular, damit Browser-Meldungen nicht fälschlich als In-App gelten. Mail-Ingress setzt `kind/feedback` und `source/email` und schreibt `issue-dev-gmail-id` (Gmail-Message-Id) in den Body, damit der Bot die MIME-Anhänge per Gmail-API laden kann. Der Bot holt die Mail nur bei Autor `github-actions[bot]` und Label `source/email`. Die Labels müssen am Repo existieren. Fehlen sie oder darf der Aufrufer keine Labels setzen, kann GitHub das Issue trotzdem anlegen — dann ohne diese Labels. HTTP 422 ist eine allgemeine Validierungs- oder Spam-Antwort, kein fester Fehlcode für fehlende Labels.

Paste-Import kann nach Bestätigung ein Issue `kind/feature` anlegen. Das Originaldokument hängt die App nicht an das Issue; es geht per E-Mail an `reisenapp100@gmail.com`. Dafür reicht dasselbe Issues-PAT; kein Contents-Recht und kein zweites Repository.

## Issue-Formulare und Chooser

SSOT: [`.github/ISSUE_TEMPLATE/`](../../.github/ISSUE_TEMPLATE/).

| Pfad | Formular | Vorausgefülltes Feld |
|------|----------|----------------------|
| Safari ohne Token (`GitHubIssueNewIssueURL`) | `bug.yml` / `feedback.yml` | `what` / `feedback` |
| Kontakt / Datenschutz (Pages) | `legal.yml` | `notice` |
| Web-Chooser | dieselben YAML-Formulare | manuell |

[`config.yml`](../../.github/ISSUE_TEMPLATE/config.yml) setzt `blank_issues_enabled: false` und `contact_links` (Security Advisory, Support-Seite, Mailto). Leere Issues sind für Maintainer weiterhin möglich; öffentliche Pages-Links nutzen deshalb `legal.yml` statt Query-`body`. Die Advisory-URL ist SSOT in `GitHubRepository.securityAdvisoryNewURL` und muss mit [`SECURITY.md`](../../SECURITY.md), [`CODE_OF_CONDUCT.md`](../../CODE_OF_CONDUCT.md) und den Formular-Markdowns übereinstimmen (Test: `githubRepository_securityAdvisoryURLsMatchPolicyAndTemplates`).

**Deploy:** `config.yml`, `legal.yml` und die Redirects [`docs/legal/contact-request.html`](../legal/contact-request.html) / [`privacy-request.html`](../legal/privacy-request.html) müssen **gemeinsam** auf dem Default-Branch landen (danach Pages-Workflow). Sonst führen die alten `body=`-Redirects bei `blank_issues_enabled: false` in den Chooser statt ins Formular. PR dafür: gemeinsamer Merge (nicht Templates ohne Redirects).

Die Issues-API (App-Token, Gmail-Ingress) **füllt keine YAML-Formulare aus**. Sie postet Markdown-Bodies (`## Zusammenfassung`, `## Diagnose`, Fingerprint bzw. `reisen-email-id`) und Labels direkt — siehe `GitHubIssueDiagnostic` und `Scripts/ingest-gmail-feedback.py`. Zusätzliche Pflichtfelder in den Formularen (außer dem Haupt-Textarea und der Datenschutz-Checkbox) würden den Safari-Pfad blockieren; optionale Triage-Felder in `bug.yml` bleiben für den Web-Chooser und werden von der App-URL nicht befüllt.

## Keine Dateianhänge

Die Issues-API mit dem eingebetteten PAT kann **keine Dateien** an Issues hängen. Automatische Fehlerberichte enthalten Diagnose, Fehlertyp/Domain/Code, Underlying-Kette, Crash-Stack und einen geschwärzten Sync-Protokoll-Auszug **als Text**. Zusätzliche Dateien (Screenshots, Archive) per E-Mail an `reisenapp100@gmail.com`; sie bleiben in der Mailbox und werden nicht auf GitHub hochgeladen. Textanhänge aus solchen Mails setzt der Gmail-Ingress geschwärzt in den Issue-Body.
