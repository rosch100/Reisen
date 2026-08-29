# Paste-Import: Feature-Request nach fehlgeschlagener Erkennung

Datum: 2026-08-29  
Status: P1 (feature-dev; Alternative gewählt)  
Basis: [2026-08-28-paste-import-design.md](2026-08-28-paste-import-design.md) (F06)  
Backlog: F06-Erweiterung, kein neues Backlog-ID

## Ziel

Wenn Paste- oder Datei-Import **keine Buchung erkennt**, kann der Nutzer **nach ausdrücklicher Bestätigung** ein öffentliches GitHub-Issue der Art **Feature-Request** anlegen. Am Issue hängt das **unveränderte Dokument** (Text, Bild oder PDF), damit die Erkennung später verbessert werden kann.

Ohne Bestätigung entsteht **kein** Issue. Der bestehende Sync-/Crash-**Auto-Report** gilt hier nicht.

## Begriffe (SSOT)

| Begriff | Bedeutung |
|---|---|
| **Erkennung nicht erfolgreich** | Der Lauf hat eine gültige Quelle, aber (a) 0 `PasteImportCandidate` nach Filter oder (b) der Extract wirft einen **Modellfehler** (`PasteImportFailure.model`). |
| **Angebot** | UI zeigt die Aktion „Als Feature-Request senden…“, weil das Domain-Gate es erlaubt. |
| **Bestätigung** | Zweites Alert: öffentlich, Dokument geht mit, Abbrechen oder Senden. Erst Senden ruft den Reporter. |
| **Feature-Request** | GitHub-Issue mit Label `kind/feature` und `source/in-app`, Titelpräfix `[Feature]`, Formular `feature.yml` / Feld `want`. |
| **Anhang** | Das Quelldokument dieser Quelle. Text im Issue-Body (redigiert). Bild/PDF als Folge-Kommentare im dokumentierten Envelope (Base64), über die **bestehende** `comment`-API. |
| **Quelle** | Dieselbe ephemere `PasteImportSource` wie F06; sie bleibt bis Dismiss/Reset erhalten, solange ein Angebot möglich ist. |

**Explizit verworfen:** `GitHubIssueAutoReport` / Settings-Toggle „Fehler automatisch melden“. Stille Übermittlung. PAT-Erweiterung (Contents, Gist, zweites Repo). Undokumentierter `uploads.github.com`-Pfad (Push-Recht, PDF 422). Gmail-Ingress als Träger (legt Dateinamen an, nicht die Datei). Speichern des Dokuments an der Buchung (F05).

## Anforderungen

### In Scope

- Angebot nur bei **Erkennung nicht erfolgreich** (0 Kandidaten oder Modellfehler), wenn eine Quelle vorliegt.
- Kein Angebot bei: leerer Quelle, Modellstufe `unavailable`, `imageUnsupported`, Share-Handoff-Fehler, Store-Ladefehler, Nutzer bricht PCC ab, Nutzer bricht den Lauf ab, Kandidatenliste mit ≥1 Eintrag.
- Bestätigungs-Alert (macOS und iOS) **vor** jedem `GitHubIssueReporter.report`. Text sagt klar: Issue ist **öffentlich**, das Dokument (PNR, Namen, Tickets) wird mitgeschickt.
- Nach Senden: Issue `kind/feature` + `source/in-app`. Titel `[Feature] Paste-Import: Dokument nicht erkannt`. Body: Grund (`noCandidates` / `model`), Quellart (Text/Bild/PDF), Diagnose wie bestehende Issues, Textquelle im Abschnitt Dokument nach `SecretRedactor`.
- Bild/PDF: unveränderte Bytes als Anhang-Kommentare. Text nicht zusätzlich als Base64, wenn er bereits im Body steht.
- Größengrenze **512_000** Bytes Rohdaten. Darüber: **kein** Issue, typisierter Fehler, Quelle bleibt für Retry nach Verkleinerung nicht still ersetzt.
- Fingerprint = `kind/feature` + SHA256 der Quellbytes (Text UTF-8 oder Bild/PDF-Data). **Nicht** den Erkennungsgrund. Derselbe Anhang nach 0 Kandidaten oder Modellfehler trifft dasselbe offene Issue. Dann **kein** zweites Create, **kein** erneutes Hochladen der Bytes (Kommentar-Throttle wie Reporter).
- Ohne eingebettetes Token: nach Bestätigung **Fehler** (`GitHubIssueTokenError`). Kein `GitHubIssueNewIssueURL`, kein `PublicGitHubIssueReportActions`. Erfolg zeigt nur `PublicGitHubIssueLink` auf die vom Reporter gelieferte URL.
- Privacy-HTML DE/EN: Feature-Request nach Bestätigung; öffentlich; Dokument geht an GitHub.
- L10n de+en für alle neuen Keys.

### Nicht in Scope

- Automatisches Senden (auch nicht bei eingeschaltetem Auto-Report).
- PAT-Scopes über Issues read/write oder andere Repositories.
- Cloud-Speicher, Gist, Repo-Dateien, Release-Assets.
- OCR oder Nachverarbeitung des Anhangs vor dem Senden.
- Drittanbieter-LLM.
- Live-GitHub-Create in CI.

## Gewählte Alternative

Drei Wege wurden verglichen:

1. **Undokumentierter User-Attachments-Upload** — braucht Push/Contents, PDF oft 422. Verworfen: Scope-Erweiterung und unsichere API.
2. **E-Mail an Feedback-Ingress** — Ingress speichert nur Dateinamen, nicht die Bytes. Verworfen: kein echter Anhang am Issue.
3. **Bestehender Issues-Client: Create + `comment` mit Envelope** (gewählt) — bleibt beim dokumentierten PAT, liefert dem Maintainer das Original, Text und Binär einheitlich über Nachbar-API `GitHubIssueSubmitting`.

Restrisiko: Base64-Kommentare sind öffentlich und zählen gegen GitHub-Limits. Die Bestätigung macht das sichtbar; das Limit 512 KiB hält die Kommentarzahl klein (Budget 60_000 Zeichen/Kommentar).

## Architektur

| Schicht | Verantwortung |
|---|---|
| **ReisenDomain** | Gate `PasteImportFailedRecognition.shouldOffer`; Grund `noCandidates` \| `model`; `PasteImportFailedDocument` (Dateiname, MIME, Bytes oder Text) aus `PasteImportSource`. Kein GitHub, kein UIKit. |
| **ReisenAppCore** | `GitHubIssueKind.feature`; Attachment-Codec; `GitHubIssueReporter.report(..., attachments:)`; `PasteImportFailedFeatureRequest.submit`; **Flow** `PasteImportFailedFeatureRequestFlow` (Angebot/Bestätigung/Submit) — eine State-Machine für macOS und iOS. Nicht `GitHubIssueAutoReport`. |
| **ReisenSharedUI** | Kandidaten-Sheet (bisher in den Apps dupliziert) inkl. Feature-Button; Bestätigungs-Presentation. Kein HTTP, kein `ReisenPasteImport`. |
| **ReisenPasteImport** | `PasteImportSession` hält Quelle + Flow (macOS und iOS). |
| **Reisen / ReiseniOS** | Alerts binden `offerFailedFeatureRequest` / `confirmFailedFeatureRequest` / `cancelFailedFeatureRequest`. |

Datenfluss:

```
Quelle + Lauf
  → 0 Kandidaten oder PasteImportFailure.model
  → Gate.shouldOffer == true
  → UI Angebot
  → Nutzer bestätigt
  → PasteImportFailedFeatureRequest.submit(source, reason)
  → GitHubIssueReporter.report(kind: .feature, attachments:)
  → createIssue | bestehendes Issue
  → comment-Hülle für Bild/PDF
```

Fehler: Token fehlt, Rate-Limit, HTTP, zu groß — UI zeigt `localizedDescription`, kein Dummy-Issue.

## Schnittstellen

| id | kind | Supply | Evidence |
|---|---|---|---|
| failed-recognition-macos | entry | Button im 0-Kandidaten-Sheet + Extra-Button im Modellfehler-Alert → Bestätigungs-Alert → `flow.confirm` | Tests: (1) Sheet-Presentation `showsFeatureRequestButton` / `continueEnabled`; (2) AppCore-Flow `offer` ohne `confirm` ruft Reporter nicht; `confirm` ruft `submit`; derselbe Flow, den Mac-Session und Host binden |
| failed-recognition-ios | entry | dieselben Controls in SharedUI-Sheet + `PasteImportHost` an denselben Flow | Host verdrahtet denselben Flow; iOS-Scheme-Test dass der Feature-Button-Callback `flow.offer` ist |
| github-issues-pat | capability | Issues read/write, Repo `rosch100/Reisen` | Doku-Assert + Stub leer; kein Contents in diesem Diff |
| offer-and-confirm-contract | contract | Gate; Reporter nur nach UI-Aufruf | Unit |
| attachment-envelope | contract | Body-Text / Base64-Kommentare | Codec + Reporter |
| github-issue-reporter | neighbor | bestehender Reporter + `comment` | Tests am Reporter, kein zweiter Client |
| live-github-create | corpus | manuell / env | CI nicht; `open_gaps` |

**port-only:** nein.

**Rauschen:** AGB-Filter der Erkennung bleibt F06. Der Feature-Request sendet das **Original**, kein gefiltertes Modell-Input.

## UI / HIG

- Leerzustand: bestehender Text `pasteImportEmpty`; zusätzlicher Button nur wenn Gate wahr (Sheet mit 0 Kandidaten).
- Modellfehler-Alert: `OK` schließt; zweiter Button startet die Bestätigung (Quelle bleibt).
- Bestätigung: Titel Feature-Request; Message öffentlich + Dokument; `Abbrechen` / `Senden`. Senden ist nicht `.destructive` (kein Löschen), aber nicht Default-Action — Default bleibt Abbrechen, damit Enter nicht sendet.
- **Abbrechen** der Bestätigung: zurück in den Angebot-Zustand (leeres Kandidaten-Sheet bzw. Modellfehler-Alert), **Quelle bleibt**. `reset` nur bei Schließen des Imports.
- Erfolg: nur `PublicGitHubIssueLink` (Reporter-URL). Nicht `PublicGitHubIssueReportActions` (das öffnet ohne Token Safari ohne Anhang).
- VoiceOver: Button-Label = sichtbarer Text.

## Privacy

`privacy.html` / `en/privacy.html`: Nach fehlgeschlagener Erkennung kann der Nutzer ein **öffentliches** GitHub-Issue mit dem Dokument erzeugen, **nur nach Bestätigung**. Ohne Bestätigung verlässt das Dokument das Gerät nicht (weiter ephemerer Import). Kein Auto-Report.

## Offene Lücken (`open_gaps`)

- Live-Create eines GitHub-Issues mit Anhang: nicht in CI (kein Token, keine Seitenwirkung aufs öffentliche Repo). Judge akzeptiert bewusst offen.

## Tests

- Gate: 0 Kandidaten → anbieten; ≥1 → nicht; `.model` → anbieten; `.source` / `.modelUnavailable` / `.imageUnsupported` → nicht.
- `PasteImportFailedDocument` aus Text/Bild/PDF (Dateiname + MIME).
- `GitHubIssueKind.feature` ↔ `feature.yml`, Labels `kind/feature,source/in-app`, Titel `[Feature]`.
- Reporter: Attachments → `create` dann `comment`s; über Limit kein `create`; ohne Token kein HTTP; Auto-Report-Pfad unverändert.
- Codec: leere Bytes Fehler; Chunk-Grenzen; Marker im Kommentar.
- L10n alle neuen Keys; Privacy-Needles (öffentlich, Bestätigung, Dokument/GitHub).
- RED = fachlicher Assert, nicht fehlende Typen.

Kein Live-Modell und kein Live-GitHub in CI.
