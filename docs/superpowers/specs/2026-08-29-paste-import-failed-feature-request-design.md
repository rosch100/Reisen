# Paste-Import: Feature-Request nach fehlgeschlagener Erkennung

Datum: 2026-08-29  
Status: P1 (feature-dev; Alternative gewählt)  
Basis: [2026-08-28-paste-import-design.md](2026-08-28-paste-import-design.md) (F06)  
Backlog: F06-Erweiterung, kein neues Backlog-ID

## Ziel

Wenn Paste- oder Datei-Import **keine Buchung erkennt**, kann der Nutzer **nach ausdrücklicher Bestätigung** ein öffentliches GitHub-Issue der Art **Feature-Request** anlegen. Das **Originaldokument** geht **nicht** an GitHub, sondern **per E-Mail** (Anhang) an die Feedback-Adresse.

Ohne Bestätigung entsteht **kein** Issue. Der bestehende Sync-/Crash-**Auto-Report** gilt hier nicht.

## Begriffe (SSOT)

| Begriff | Bedeutung |
|---|---|
| **Erkennung nicht erfolgreich** | Der Lauf hat eine gültige Quelle, aber (a) 0 `PasteImportCandidate` nach Filter oder (b) der Extract wirft einen **Modellfehler** (`PasteImportFailure.model`). |
| **Angebot** | UI zeigt die Aktion „Als Feature-Request senden…“, weil das Domain-Gate es erlaubt. |
| **Bestätigung** | Zweites Alert: Issue ist öffentlich, Dokument geht per E-Mail (nicht an GitHub). Abbrechen oder Senden. Erst Senden ruft den Reporter. |
| **Feature-Request** | GitHub-Issue mit Label `kind/feature` und `source/in-app`, Titelpräfix `[Feature]`, Formular `feature.yml` / Feld `want`. |
| **Anhang** | Das Quelldokument dieser Quelle, **nur in der E-Mail** an `GitHubRepository.feedbackEmail`. Nicht im Issue-Body, nicht als GitHub-Kommentar, nicht als Datei-Upload. |
| **Quelle** | Dieselbe ephemere `PasteImportSource` wie F06; sie bleibt bis Dismiss/Reset erhalten, solange ein Angebot möglich ist. |

**Explizit verworfen:** `GitHubIssueAutoReport` / Settings-Toggle „Fehler automatisch melden“. Stille Übermittlung. PAT-Erweiterung (Contents, Gist, zweites Repo). Undokumentierter `uploads.github.com`-Pfad. Base64-Kommentare oder Dokumenttext im öffentlichen Issue. Öffentliche Share-Links (iCloud/Drive) im Issue. Gmail-Ingress, der das Beispieldokument erneut als öffentliches Issue anlegt. Speichern des Dokuments an der Buchung (F05).

## Anforderungen

### In Scope

- Angebot nur bei **Erkennung nicht erfolgreich** (0 Kandidaten oder Modellfehler), wenn eine Quelle vorliegt.
- Kein Angebot bei: leerer Quelle, Modellstufe `unavailable`, `imageUnsupported`, Share-Handoff-Fehler, Store-Ladefehler, Nutzer bricht PCC ab, Nutzer bricht den Lauf ab, Kandidatenliste mit ≥1 Eintrag.
- Bestätigungs-Alert (macOS und iOS) **vor** jedem `GitHubIssueReporter.report`. Text sagt klar: Issue ist **öffentlich**, das Dokument geht **per E-Mail**, nicht an GitHub.
- Nach Senden: Issue `kind/feature` + `source/in-app`. Titel `[Feature] Paste-Import: Dokument nicht erkannt`. Body: Grund (`noCandidates` / `model`), Quellart (Text/Bild/PDF), Diagnose wie bestehende Issues, Hinweis auf E-Mail. **Kein** Buchungstext, **keine** Dateibytes.
- Nach erfolgreichem Issue: Mail-Composer (Anhang = Original). Marker `reisen-paste-import-document` im Mailtext. Gmail-Ingress legt dafür **kein** zweites Issue an.
- Fingerprint = `kind/feature` + SHA256 der Quellbytes (Text UTF-8 oder Bild/PDF-Data). **Nicht** den Erkennungsgrund. Derselbe Anhang nach 0 Kandidaten oder Modellfehler trifft dasselbe offene Issue. Dann **kein** zweites Create.
- Ohne eingebettetes Token: nach Bestätigung **Fehler** (`GitHubIssueTokenError`). Kein `GitHubIssueNewIssueURL`, kein `PublicGitHubIssueReportActions`. Erfolg zeigt nur `PublicGitHubIssueLink` auf die vom Reporter gelieferte URL.
- Privacy-HTML DE/EN: Feature-Request nach Bestätigung; öffentlich ohne Dokument; Dokument per E-Mail.
- L10n de+en für alle neuen Keys.

### Nicht in Scope

- Automatisches Senden (auch nicht bei eingeschaltetem Auto-Report).
- PAT-Scopes über Issues read/write oder andere Repositories.
- Cloud-Speicher, Gist, Repo-Dateien, Release-Assets.
- OCR oder Nachverarbeitung des Anhangs vor dem Senden.
- Drittanbieter-LLM.
- Live-GitHub-Create in CI.

## Gewählte Alternative

GitHub hat **keine** dokumentierte Datei-Upload-API für Issues mit dem Issues-only-PAT. Öffentliche Issues dürfen keine Buchungsdokumente oder weltlesbaren Share-Links enthalten.

Gewählt: **Metadaten-Issue + E-Mail-Anhang.** Das Dokument bleibt im Gmail-Postfach. Der Ingress überspringt Mails mit `reisen-paste-import-document`.

## Architektur

| Schicht | Verantwortung |
|---|---|
| **ReisenDomain** | Gate `PasteImportFailedRecognition.shouldOffer`; Grund `noCandidates` \| `model`; `PasteImportSource` trägt Dateiname, MIME und Bytes für den Mail-Anhang. Kein GitHub, kein UIKit. |
| **ReisenAppCore** | `GitHubIssueKind.feature`; `PasteImportFailedMailDraft`; `PasteImportFailedFeatureRequest.submit`; **Flow** inkl. Mail-Draft. Nicht `GitHubIssueAutoReport`. Kein Dokument am Issue. |
| **ReisenSharedUI** | `pasteImportFlow` inkl. Feature-Button und Bestätigungs-Presentation. Kein HTTP, kein `ReisenPasteImport`. |
| **ReisenPasteImport** | `PasteImportSession` hält Quelle + Flow-Zustand (macOS und iOS). |
| **Reisen / ReiseniOS** | Host/MacUI rufen `pasteImportFlow` auf. |

Datenfluss:

```
Quelle + Lauf
  → 0 Kandidaten oder PasteImportFailure.model
  → Gate.shouldOffer == true
  → UI Angebot
  → Nutzer bestätigt
  → PasteImportFailedFeatureRequest.submit(source, reason)
  → GitHubIssueReporter.report(kind: .feature)  // ohne attachments
  → Mail-Composer mit Originalanhang
```

Fehler: Token fehlt, Rate-Limit, HTTP — UI zeigt `localizedDescription`, kein Dummy-Issue.

## Schnittstellen

| id | kind | Supply | Evidence |
|---|---|---|---|
| failed-recognition-macos | entry | Button im 0-Kandidaten-Sheet + Extra-Button im Modellfehler-Alert → Bestätigungs-Alert → `flow.confirm` | Tests: (1) Sheet-Presentation `showsFeatureRequestButton` / `continueEnabled`; (2) AppCore-Flow `offer` ohne `confirm` ruft Reporter nicht; `confirm` ruft `submit`; derselbe Flow, den Mac-Session und Host binden |
| failed-recognition-ios | entry | dieselben Controls in SharedUI-Sheet + `PasteImportHost` an denselben Flow | Host verdrahtet denselben Flow; iOS-Scheme-Test dass der Feature-Button-Callback `flow.offer` ist |
| github-issues-pat | capability | Issues read/write, Repo `rosch100/Reisen` | Doku-Assert + Stub leer; kein Contents in diesem Diff |
| offer-and-confirm-contract | contract | Gate; Reporter nur nach UI-Aufruf | Unit |
| mail-document | contract | E-Mail-Anhang, Ingress-Skip-Marker | Mail-Draft + ingest-Test |
| github-issue-reporter | neighbor | bestehender Reporter ohne Attachments für diesen Pfad | Tests am Reporter, kein zweiter Client |
| live-github-create | corpus | manuell / env | CI nicht; `open_gaps` |

**port-only:** nein.

**Rauschen:** AGB-Filter der Erkennung bleibt F06. Das Original geht per E-Mail, ungefiltert.

## UI / HIG

- Leerzustand: bestehender Text `pasteImportEmpty`; zusätzlicher Button nur wenn Gate wahr (Sheet mit 0 Kandidaten).
- Modellfehler-Alert: `OK` schließt; zweiter Button startet die Bestätigung (Quelle bleibt).
- Bestätigung: Titel Feature-Request; Message öffentlich + Dokument; `Abbrechen` / `Senden`. Senden ist nicht `.destructive` (kein Löschen), aber nicht Default-Action — Default bleibt Abbrechen, damit Enter nicht sendet.
- **Abbrechen** der Bestätigung: zurück in den Angebot-Zustand (leeres Kandidaten-Sheet bzw. Modellfehler-Alert), **Quelle bleibt**. `reset` nur bei Schließen des Imports.
- Erfolg nach Mail: Session `reset()`; kein Erfolg-Sheet mit GitHub-Link (Issue wurde schon vor der Mail angelegt).
- Erfolg-Sheet mit `PublicGitHubIssueLink` **nur** wenn Mail unavailable (`canSend == false`). Nicht `PublicGitHubIssueReportActions` (öffnet ohne Token Safari ohne Anhang).
- macOS: Mail-Übergabe als RFC822-`.eml` per `NSWorkspace` (Default-Mailer), nicht `NSSharingService` mit Body+Datei-URL.
- VoiceOver: Button-Label = sichtbarer Text.

## Privacy

`privacy.html` / `en/privacy.html`: Nach fehlgeschlagener Erkennung kann der Nutzer ein **öffentliches** GitHub-Issue **ohne Dokument** erzeugen, **nur nach Bestätigung**. Das Original geht **per E-Mail**, wenn Mail eingerichtet ist (`canSend == true`). Ist Mail unavailable (`canSend == false`), bleibt das Dokument auf dem Gerät; nur der öffentliche Issue-Link (Metadaten, ohne Anhang) wird angeboten. Ohne Bestätigung verlässt das Dokument das Gerät nicht.

## Offene Lücken (`open_gaps`)

- Live-Create des Metadaten-Issues und Mail-Draft mit Anhang: nicht in CI (kein Token, keine Seitenwirkung aufs öffentliche Repo). Judge akzeptiert bewusst offen.

## Tests

- Gate: 0 Kandidaten → anbieten; ≥1 → nicht; `.model` → anbieten; `.source` / `.modelUnavailable` / `.imageUnsupported` → nicht.
- `PasteImportSource`: Dateiname, MIME und Payload für Text/Bild/PDF.
- `GitHubIssueKind.feature` ↔ `feature.yml`, Labels `kind/feature,source/in-app`, Titel `[Feature]`.
- Reporter: Feature-Request ohne Attachments; Textquelle nicht im Body.
- Mail-Draft: Anhangbytes, Marker, Feedback-Adresse.
- L10n alle neuen Keys; Privacy-Needles (öffentlich, Bestätigung, per E-Mail / by email).
- RED = fachlicher Assert, nicht fehlende Typen.

Kein Live-Modell und kein Live-GitHub in CI.
