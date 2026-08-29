# Gmail-Feedback → GitHub-Issues

Ungelesene Mails an **reisenapp100@gmail.com** (`GitHubRepository.feedbackEmail`) werden alle 15 Minuten zu öffentlichen Issues.

Ablauf: Gmail API (OAuth Refresh-Token) → `Scripts/ingest-gmail-feedback.sh` → `POST /repos/rosch100/Reisen/issues` als `github-actions[bot]`.

Labels: `kind/feedback`, `source/email`. Titel: `[Feedback] ` plus Betreff (max. 80 Zeichen). Duplikate: Marker `reisen-email-id` im Issue-Body. Der Grok-Bot lädt Anhänge nicht von GitHub, sondern liest die Mail per Gmail-API: Marker `issue-dev-gmail-id` (Gmail-Message-Id; letzte HTML-Kommentar-Instanz). Ingress entfernt HTML-Kommentare aus Mailfeldern. Siehe [issue-dev.md](issue-dev.md).

Die Logik liegt nur im Script; der Workflow [gmail-feedback-ingress.yml](../../.github/workflows/gmail-feedback-ingress.yml) ruft das Script auf.

Mails, deren **erste nichtleere Zeile genau** `reisen-paste-import-document` ist (Paste-Import-Beispieldokument nach fehlgeschlagener Erkennung), werden **nicht** zu GitHub-Issues. Ein Präfix wie `reisen-paste-import-documentation` und ein Zitat des Markers mitten in einer normalen Feedback-Mail zählen nicht. Der Ingress markiert passende Mails als gelesen; der Anhang bleibt im Gmail-Postfach. So landet das Dokument nicht öffentlich auf GitHub.

Nach erfolgreichem Issue-Create feuert GitHub `issues: opened` → [issue-dev-wake.yml](../../.github/workflows/issue-dev-wake.yml). Der Bot nutzt **kein IMAP**; er holt dieselbe Mail per Gmail-API (OAuth, `issue-dev-gmail-id`). Siehe [issue-dev.md](issue-dev.md).

Kein App-Passwort, kein IMAP, kein Google-Konto-Passwort.

## Secrets

| Name | Inhalt |
|------|--------|
| `REISEN_GMAIL_OAUTH_CLIENT_ID` | OAuth-Client-ID (Desktop-App) |
| `REISEN_GMAIL_OAUTH_CLIENT_SECRET` | OAuth-Client-Secret |
| `REISEN_GMAIL_OAUTH_REFRESH_TOKEN` | Refresh-Token für `reisenapp100@gmail.com` |

Die Adresse ist öffentlich und **kein** Secret. SSOT: `GitHubRepository.feedbackEmail` und `DEFAULT_FEEDBACK_EMAIL` in `Scripts/ingest-gmail-feedback.py`.

GitHub-API: `GITHUB_TOKEN` des Workflows (`issues: write`).

Lokal ohne OAuth-Secrets: Exit 0, `ingest übersprungen, Secret fehlt`. Unter `GITHUB_ACTIONS=true` ist fehlendes Secret Exit 1.

Scope: `https://www.googleapis.com/auth/gmail.modify` (ungelesene Inbox lesen und nach Erfolg als gelesen markieren).

## Einmalig einrichten

Nicht in Gmail unter **Verknüpfte Apps** (das ist nur die Liste nach der Zustimmung). Nicht auf den Marketing-Seiten von Google Cloud oder Google Workspace.

Die Entwickler-Console ist für ein **privates Gmail** gedacht, ohne Firma und ohne Workspace: [console.cloud.google.com](https://console.cloud.google.com/), angemeldet als `reisenapp100@gmail.com` (privates Browserfenster, falls noch ein Arbeitskonto aktiv ist). OAuth-Client und Gmail API kosten nichts; eine Zahlungsart ist dafür nicht nötig.

### 1. Console öffnen und Projekt anlegen

1. Privates Fenster, nur `reisenapp100@gmail.com`.
2. [console.cloud.google.com](https://console.cloud.google.com/) öffnen. Nutzungsbedingungen akzeptieren, falls gefragt. Keine Workspace- oder „Für Unternehmen“-Seite verwenden.
3. Oben auf den Projektnamen bzw. **Select a project** → **New project**.
4. Name z. B. `Reisen Feedback`. Organisation leer lassen. **Create**.
5. Das neue Projekt in der Leiste auswählen.

### 2. Gmail API einschalten

1. [Gmail API](https://console.cloud.google.com/apis/library/gmail.googleapis.com) öffnen.
2. **Enable** / **Aktivieren**.

### 3. Google Auth platform (Zustimmungsbildschirm)

1. [Google Auth platform](https://console.cloud.google.com/auth/overview) öffnen.
2. Falls **Google Auth platform not configured yet**: **Get Started**.
3. App name: `Reisen Feedback Ingress`.
4. User support email: `reisenapp100@gmail.com`.
5. **Audience**: **External** (`Internal` erscheint nur bei Google Workspace und ist hier falsch).
6. Contact email: `reisenapp100@gmail.com`.
7. Google API Services User Data Policy akzeptieren → **Create**.
8. **Audience** → **Test users** → **Add users** → `reisenapp100@gmail.com` → **Save**. Publishing darf zuerst **Testing** bleiben (sonst blockt Google den ersten Login). Nach dem Refresh-Token auf **In production** stellen — siehe unten.
9. **Data Access** → **Add or remove scopes** → Filter `Gmail` → `https://www.googleapis.com/auth/gmail.modify` (Gmail API, `.../auth/gmail.modify`) auswählen → **Update** → **Save**.

Ohne diesen Testnutzer blockt Google den Login mit „App is blocked“ / Zugriff verweigert.

### 4. OAuth-Client (Desktop)

1. [Clients](https://console.cloud.google.com/auth/clients) → **Create client**.
2. Application type: **Desktop app**.
3. Name z. B. `Reisen Feedback Ingress Desktop`.
4. **Create**. Client-ID und Client-Secret in einen Passwortmanager, **nicht** ins Git. JSON-Download ist optional; die Werte reichen.

Desktop-Clients erlauben Loopback `http://127.0.0.1:8765/` von selbst. Keine Redirect-URI eintragen.

### 5. Einmalig lokal zustimmen

Im Worktree bzw. Repo-Checkout, der `Scripts/authorize-gmail-feedback-oauth.sh` enthält. Secrets nicht in die Shell-History kopieren, wenn vermeidbar (`read -s` oder Werte nur in der Session).

```bash
cd /Users/roschmac/Entwicklung/Reisen/.worktrees/feedback-gmail-store-token
export REISEN_GMAIL_OAUTH_CLIENT_ID='…'
export REISEN_GMAIL_OAUTH_CLIENT_SECRET='…'
bash ./Scripts/authorize-gmail-feedback-oauth.sh
```

1. Der Browser öffnet Google. Konto **reisenapp100@gmail.com** wählen (nicht das Alltags-Gmail).
2. Warnung **Google hat diese App nicht bestätigt**: **Erweitert** → **Zu Reisen Feedback Ingress (unsicher)**. Normal, solange die App nicht von Google verifiziert ist.
3. Gmail-Zugriff erlauben.
4. Seite „Autorisierung abgeschlossen“ — Fenster schließen.
5. Das Terminal schreibt den Refresh-Token nach **stdout**. Das ist `REISEN_GMAIL_OAUTH_REFRESH_TOKEN`. Nicht committen, nicht in Issues/Chats legen.

### 6. GitHub-Secrets

[Repo-Secrets](https://github.com/rosch100/Reisen/settings/secrets/actions):

| Name | Inhalt |
|------|--------|
| `REISEN_GMAIL_OAUTH_CLIENT_ID` | Client-ID aus Schritt 4 |
| `REISEN_GMAIL_OAUTH_CLIENT_SECRET` | Client-Secret aus Schritt 4 |
| `REISEN_GMAIL_OAUTH_REFRESH_TOKEN` | stdout aus Schritt 5 |

Altes Secret `REISEN_FEEDBACK_GMAIL_APP_PASSWORD` löschen, falls vorhanden. `GITHUB_TOKEN` nicht anlegen (kommt vom Workflow).

### 7. Label und Test

1. Label [`source/email`](https://github.com/rosch100/Reisen/labels) anlegen (`kind/feedback` existiert über das Issue-Formular).
2. Der Workflow **Gmail Feedback Ingress** erscheint in Actions erst, wenn die YAML auf **`master`** liegt.
3. Testmail an `reisenapp100@gmail.com` → Actions → **Gmail Feedback Ingress** → `workflow_dispatch` → Issue mit Labels `kind/feedback` und `source/email` prüfen.

Danach darf **Verknüpfte Apps** / [Drittanbieter-Zugriff](https://myaccount.google.com/connections) den Eintrag `Reisen Feedback Ingress` zeigen. Vor der Zustimmung bleibt die Liste leer.

## Refresh-Token-Laufzeit

Der Ingress erneuert **Access-Tokens** bei jedem Lauf selbst. Das ist schon automatisiert. Ein abgelaufenes **Refresh-Token** kann Google nicht ohne Browser-Zustimmung ersetzen — das lässt sich nicht per Cron umgehen.

Die 7-Tage-Frist gilt nur bei Publishing **Testing**. Für dieses Ein-Personen-Setup:

1. [Audience](https://console.cloud.google.com/auth/audience) → **Publish app** / **In production**.
2. Keine Google-Verifizierung nötig (persönliche Nutzung, ein Konto). Die App bleibt „unverified“.
3. `authorize-gmail-feedback-oauth.sh` **danach noch einmal** ausführen. Tokens aus der Testing-Phase behalten die 7-Tage-Frist.
4. Nur Secret `REISEN_GMAIL_OAUTH_REFRESH_TOKEN` ersetzen.

Danach bleibt das Refresh-Token gültig, bis Zugriff widerrufen wird, das Gmail-Passwort geändert wird oder es sechs Monate ungenutzt bleibt. Google-Verifizierung (CASA) ist für fremde Nutzer und öffentliche Gmail-Scopes gedacht, nicht für dieses Setup.

## Lokal ohne Netz

```bash
bash ./Scripts/ingest-gmail-feedback.sh --eml-file Scripts/tests/ingest-gmail-feedback/fixtures/plain.eml --dry-run
```

Parser-Tests laufen in `Scripts/ci-test.sh`.
