# macOS UI-Tests auf Remote-Host (Working-Tree-Sync)

**Datum:** 2026-09-02  
**Status:** freigegeben (Brainstorming + Spec-Review; Findings eingearbeitet)  
**Abhängigkeit:** [`2026-08-30-macos-ui-surface-test-design.md`](2026-08-30-macos-ui-surface-test-design.md) — Testvertrag unverändert; dieses Dokument steuert **wo** `macos-ui-test.sh` läuft und (Rev 7) welche Selection-Args durchgereicht werden. Selection-Semantik: [`2026-09-04-macos-ui-diff-select-design.md`](2026-09-04-macos-ui-diff-select-design.md).

## Änderungsprotokoll

### Rev 1 — Spec-Review (Konformität / Vollständigkeit)

- Worktree-Quellen: erlaubt; `.git`-Datei wird excluded (kein Common-Dir-Partial-Sync). Primär-Checkout spiegelt `.git` Directory mit.
- Pflicht-Excludes für Secrets/PII analog `.gitignore`.
- Remote-Invoke: Absolutpfad, korrektes Quoting (`$REMOTE_DIR` nicht in einfachen Quotes).
- `rsync --delete`: Remote-Dir = reiner Spiegel; Warnung im Vertrag.
- Homebrew-PATH unter SSH; SSH-Keepalive; Xcode-`xcode-select`-Remediation; TCC/Screen-Unlock.
- Host v1 nur `imac-3.local`; `imac.altanis.de` Folgespec.
- Maintainer-Defaults als Konvention markiert; Self-Test um Exclude-/Quoting-Checks erweitert.

### Rev 2 — Host-Auflösung

- Primär: `imac.altanis.de` (SSH-Preflight).
- Fallback: Bonjour/`*.local`-Discovery `imac` / `imac-*` (case-insensitive); bei **genau einem** erreichbaren Treffer diesen nutzen; bei **0 oder &gt;1** Fail-fast mit Liste (kein stilles Raten).
- `REISEN_UI_REMOTE_HOST` gesetzt → Discovery überspringen.

### Rev 3 — Multi-Interface (LAN/WLAN)

- `imac.local` und `imac-N.local` können **dieselbe Maschine** über LAN vs. WLAN sein (verschiedene IPs), nicht zwei Hosts.
- Mehrere Bonjour-Treffer: per kurzem SSH-Identity-Probe (`hostname` o. ä.) gruppieren. **Ein** physischer Host → gültig; Interface mit **niedrigster RTT** wählen (LAN bevorzugen). **Mehrere** unterschiedliche Identities → weiterhin Fail-fast + Liste.
- `REISEN_UI_REMOTE_HOST` gesetzt → Discovery überspringen.

### Rev 4 — GUI ohne Nutzerdialog / Signing / Spec-Sync

- Ausführung: `open -a Terminal` + Profil `ReisenUIRemote` (`shellExitAction=0`) + Runner `exit 0` nach Status — **kein** AppleScript-`close` (Dialog „Prozesse beenden?“).
- Xcode-Gate: `DEVELOPER_DIR` auf Xcode.app/Xcode-beta ≥27 (ohne sudo/`xcode-select`).
- Remote-Signing: `REISEN_MAC_UI_CODE_SIGNING_OFF` → `build-for-testing` unsigned → Ad-hoc-`codesign` + `xattr -cr` → `test-without-building` (vermeidet Gatekeeper „beschädigt“).
- Architektur-Diagramm und XCUI-Snippet an Terminal-Pfad angepasst (nicht mehr `launchctl asuser`).

### Rev 5 — Restpunkte (TCC / HostKey / Gates)

- Kein `osascript` mehr: Default-Profil nur bis `open`, dann sofort restore (Fenster behält Profil; kein Automation-TCC).
- `StrictHostKeyChecking=yes` (Override: `REISEN_UI_REMOTE_STRICT_HOST_KEY=accept-new` für Erstkontakt).
- Gate: `python3` remote Pflicht; Terminal-Profil-Setup fail-fast.
- `REISEN_UI_REMOTE_FETCH_XCRESULT=1`: Fetch-Fehler nicht mehr verschluckt.
- Agent-Workflow: XCUI-Verifikation **muss** remote auf dem iMac (`macos-ui-test-remote.sh`); lokal nur nach Remote-Ausfall. Worktree-Quellen erlaubt.

### Rev 6 — Parallel-Agent-Isolation

- **Problem:** Lock galt nur für den Test-SSH; `rsync --delete` und shared `/tmp/reisen-macos-ui-run.*` kollidierten zwischen Agents.
- **Lösung:** Exklusiv-Lock über Sync→Test→Fetch; isoliertes Run-Dir `${REISEN_UI_REMOTE_DIR}/<run-id>/` (Default-Basis `~/Entwicklung/Reisen-ui-runs`); run-scoped Status/Log/Command unter `/tmp/reisen-macos-ui-run-<run-id>.*`; Stale-Lock-Steal wenn Owner älter als 45 min und kein `macos-ui-test.sh`; erfolgreicher Lauf löscht das Run-Dir, Fehlschlag belässt es zur Diagnose.

### Rev 7 — Test-Arg-Passthrough (Diff-Selektion lokal)

- **Problem:** Diff-Selektion braucht lokales Git; Worktree-Sync excludet `.git` → Selektion darf nicht remote laufen.
- **Lösung:** Wrapper berechnet Selection **lokal** (siehe [`2026-09-04-macos-ui-diff-select-design.md`](2026-09-04-macos-ui-diff-select-design.md)); bei Skip Exit 0 ohne Sync; sonst leitet er `--full` bzw. `--reisen-ui-only-testing` + `-only-testing:…` an remote `macos-ui-test.sh` durch. Keine Diff-Logik auf dem iMac.
- Satz „Wrapper dupliziert keine Test-Flags“ gilt nur noch für Generate/`xcodebuild`-Flags **außer** diesem expliziten Selection-Passthrough.

## Ziel

UI-Smokes (`Scripts/macos-ui-test.sh`) auf einem **anderen Mac** ausführen (kein GitHub Actions Runner), konkret dem iMac, mit dem **aktuellen Working Tree** inkl. uncommitteter Änderungen vom Entwickler-Mac.

## Nicht-Ziele

- Kein Ersatz für das CI-Gate auf `xcode-27`
- Kein Auto-Install von Xcode 27
- Kein `workflow_dispatch` / Runner-Registrierung
- Keine Remote-Variante von `macos-ui-review.sh` in v1
- Kein Git-Push/Pull als Sync-Pfad (nur Working-Tree-`rsync`)

## Entscheidung

| Thema | Wahl |
| --- | --- |
| Sync | `rsync` des lokalen Working Trees in **Run-Dir** (Option 1) |
| Host (v1) | Resolve: `imac.altanis.de` zuerst, sonst Bonjour `imac*.local`; bei mehreren Interfaces derselben Maschine LAN (niedrigste RTT) |
| Parallelität | Ein XCUI-Lauf gleichzeitig (Lock); Trees isoliert pro `run-id` |
| Ausführung | Lokal Selection/Skip/`--full`; remote `macos-ui-test.sh` mit Passthrough-Args |
| GUI | `open -a Terminal` + Profil `ReisenUIRemote` (Auto-Close); kein `launchctl asuser` |
| Xcode | `DEVELOPER_DIR` → Xcode ≥27 unter `/Applications`; Installation manuell |
| Signing (Remote) | `REISEN_MAC_UI_CODE_SIGNING_OFF`: unsigned build → Ad-hoc resign → test-without-building |
| Quelle | Primär-Checkout (`.git` Directory) **oder** Git-Worktree (`.git` Datei → `.git` exclude) |

## Architektur

```text
Lokal (Dev-Mac)                         Remote (iMac, GUI-Login)
─────────────────                       ────────────────────────
macos-ui-test-remote.sh
  0. Selection lokal (diff / --full / Skip→Exit 0)
  1. Host auflösen (altanis → Bonjour-Fallback)
  2. SSH-Preflight (+ Keepalive)
  3. Quelle prüfen (Primär `.git` Directory oder Worktree `.git` Datei)
  4. Gates (Xcode≥27 via DEVELOPER_DIR, brew PATH, xcodegen, console user)
  5. Exklusiv-Lock erwerben (warten / Stale-Steal)
  6. rsync Working Tree  ─────────────► ~/Entwicklung/Reisen-ui-runs/<run-id>/
  7. Terminal-Profil ReisenUIRemote + open .command
       → macos-ui-test.sh --full | --reisen-ui-only-testing …
         (Signing-Off-Pfad; run-scoped /tmp; keine Diff-Selektion remote)
  8. optional xcresult ◄─────────────── <run-dir>/DerivedData/ReisenMacUITests/
  9. Lock freigeben; Run-Dir bei Exit 0 löschen
```

Remote-GUI: Tests laufen in Terminal via `open` (SSH hat keine Audit-Session). Fenster schließen sich **ohne Nutzerdialog** über Terminal-Profil `ReisenUIRemote` (`shellExitAction=0`) und `exit 0` nach Status-Schreiben — **kein** AppleScript-`close` (würde „laufende Prozesse beenden?“ auslösen).

`macos-ui-test.sh` bleibt SSOT für Generate + `xcodebuild`. Der Wrapper berechnet Test-Selection lokal und reicht nur Selection-Args durch (`--full` / `--reisen-ui-only-testing` …); er dupliziert keine sonstigen `xcodebuild`-Flags. Remote setzt `REISEN_MAC_UI_CODE_SIGNING_OFF=true` (nicht `CI`).

## Komponenten

### `Scripts/macos-ui-test-remote.sh`

- Bash 3.2, `set -euo pipefail`, UTF-8 ohne BOM
- CLI: `--full` | Default Diff-Selektion lokal; Skip → Exit 0 ohne rsync; sonst Passthrough an remote `macos-ui-test.sh`
- `--self-test`: lokales Parsing der Env-Defaults, Exclude-Liste enthält Pflicht-Secrets-Pfade, Quoting-Probe für Remote-Invoke inkl. Passthrough-Args, Host-Resolve-Reihenfolge (kein Netz/SSH)
- Remote-Befehle immer über `bash -lc` bzw. `bash -c` (Remote-Default-Shell kann fish sein)
- SSH: `BatchMode=yes`, `ConnectTimeout=8`, `ServerAliveInterval=30`, `ServerAliveCountMax=120`, `StrictHostKeyChecking=yes` (Override `REISEN_UI_REMOTE_STRICT_HOST_KEY`)
- Exit-Code: SSH liefert den Exit-Code des Remote-`macos-ui-test.sh` unverändert durch
- Terminal: Profil `ReisenUIRemote`; Default nur bis `open`, dann restore — kein `osascript`

### Umgebung

| Variable | Default | Bedeutung |
| --- | --- | --- |
| `REISEN_UI_REMOTE_HOST` | unset | Wenn gesetzt: fester SSH-Host, **keine** Discovery. Wenn unset: Host-Auflösung (unten). |
| `REISEN_UI_REMOTE_USER` | `roschmac` | SSH-User (Maintainer-Default) |
| `REISEN_UI_REMOTE_DIR` | `~/Entwicklung/Reisen-ui-runs` | **Basis** für Run-Dirs; tatsächliches Sync-Ziel = `${DIR}/<run-id>/` (Absolutpfad remote expandiert) |
| `REISEN_UI_REMOTE_FETCH_XCRESULT` | unset/leer = aus | bei `1`: xcresult nach lokal `DerivedData/ReisenMacUITests-remote/` (Fetch-Fehler → Exit ≠ 0) |
| `REISEN_UI_REMOTE_STRICT_HOST_KEY` | `yes` | SSH `StrictHostKeyChecking`; Erstkontakt: `accept-new` |
| `REISEN_UI_REMOTE_RUN_ID` | auto (`YYYYMMDDThhmmss-<pid>-<rand>`) | Override für Diagnose; steuert Run-Dir- und `/tmp`-Namen |

SSH-Ziel nach Resolve: `${REISEN_UI_REMOTE_USER}@${resolved_host}`. Gewählter Host wird auf stderr geloggt.

### Host-Auflösung

Nur wenn `REISEN_UI_REMOTE_HOST` **nicht** gesetzt ist:

1. **Primär:** `imac.altanis.de` — SSH-Preflight (`BatchMode`, kurzer `ConnectTimeout`). Erfolg → Host = `imac.altanis.de`.
2. **Fallback (Bonjour / mDNS):** Kandidaten sammeln:
   - `dns-sd` Browse `_ssh._tcp` in `local.` und Instance-Namen, die case-insensitive zu `^imac([-].*)?$` passen (z. B. `iMac`, `iMac-3`), auf Hostnamen `….local` auflösen; **und/oder**
   - bekannte Muster probeweise: `imac.local`, `imac-*.local` (z. B. numerische Suffixe 1–9), die per mDNS auflösbar sind.
3. Jeden Kandidaten mit SSH-Preflight prüfen; nur **erreichbare** behalten. Pro erreichbarem Kandidat messen: Verbindungs-RTT (oder `ping` RTT als Näherung) und kurze Identity (`ssh … 'hostname'` — gleicher String = dieselbe Maschine, auch bei unterschiedlichen IPs/Interfaces).
4. Ergebnis:
   - **keiner** → Exit ≠ 0 („Primär und Bonjour ohne SSH-Treffer“);
   - **eine Identity**, ein oder mehrere Interfaces → Host = Interface mit **niedrigster RTT** (typisch LAN vor WLAN). Tie-Break: Name ohne numerisches Suffix (`imac.local`) vor `imac-N.local`, dann lexikalisch. Gewählten Namen + RTT auf stderr loggen;
   - **mehrere unterschiedliche Identities** → Exit ≠ 0 und Liste `(host, identity)` (kein stilles Raten; Override via `REISEN_UI_REMOTE_HOST`).

`dns-sd`-Browse mit kurzem Timeout (wenige Sekunden); hängende Discovery ist kein erlaubter Dauerzustand.

### Sync-Quelle (lokal)

1. Repo-Root = Verzeichnis, aus dem das Script läuft (`Scripts/../`), normalisiert mit `cd`/`pwd`.
2. **Gate:** `$ROOT` muss ein Git-Repo sein:
   - `.git` **Directory** (Primär-Checkout) → `.git` wird mitgespiegelt;
   - `.git` **Datei** mit `gitdir:` (Worktree) → Working Tree wird gespiegelt, **`.git` excluded** (kein Common-Dir-Partial-Sync). Agents dürfen und sollen aus dem Feature-Worktree remote starten.
3. `.worktrees/` unter dem Primär-Checkout bleibt excluded (kein Sync „von außen“ in alle Worktrees); Quelle ist jeweils der Checkout/`cd`-Root des Wrappers.

### Parallelität / Lock

1. Remote-Lock: `/tmp/reisen-macos-ui-run.lock` (mkdir-Mutex).
2. Scope: **vor** rsync bis **nach** optionalem xcresult-Fetch (nicht nur Test-SSH).
3. Owner-Datei `lock/owner` = `run-id` + Unix-Zeit; Steal wenn Alter ≥ 45 min und kein `macos-ui-test.sh` läuft.
4. Warte-Timeout 30 min (Exit 73) unverändert.
5. GUI/XCUI bleibt single-flight; isolierte Run-Dirs verhindern Tree-Zerstörung wartender Agents.

### rsync

- Flags: `-a --delete` — **Run-Dir** ist reiner Spiegel des lokalen Trees. Nicht den Maintainer-Checkout unter `~/Entwicklung/Reisen` als Default-Ziel nutzen.
- Quelle: lokaler `$ROOT/` (trailing slash), Ziel: `${ABS_BASE}/${RUN_ID}/`.
- `.git` **mitnehmen** nur beim Primär-Checkout; bei Worktree-Quelle `.git` **exclude**.
- Exclude mindestens (Pflicht):
  - Build/Generated: `.build/`, `DerivedData/`, `*.xcodeproj/`, `*.xcworkspace/` (außer bewusst keine Defaults nötig), `.sweetpad/`, `buildServer.json`, `*.xcresult`, `*.profraw`
  - Isolation: `.worktrees/`, `.superpowers/`
  - Secrets/PII: ganzes `Secrets/`, `.signing/`, `HAR/`, `*.har`, `.netrc`
  - Generated Token: `Sources/ReisenAppCore/GitHubIssues/GitHubIssueToken.generated.swift`

**Secrets-Regel:** Untracked Secrets werden **nicht** auf den Remote gespiegelt. UI-Tests brauchen das PAT nicht (`REISEN_GITHUB_ISSUE_TOKEN_EMPTY` setzt bereits `macos-ui-test.sh`).

### Remote-Gates (Fail-fast)

1. Host aufgelöst; SSH zum gewählten Host erreichbar (`BatchMode`)
2. Console-User (`stat -f %Su /dev/console`) == SSH-User
3. PATH für Homebrew: vor Checks `eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null)"` bzw. `/usr/local` — sonst False-Negative unter Non-Login-SSH
4. `DEVELOPER_DIR` auf Xcode ≥27 unter `/Applications` (`Xcode.app`, sonst `Xcode-beta.app`) — ohne sudo, auch wenn `xcode-select` auf CLT zeigt
5. `xcodegen` im PATH nach brew-shellenv — fehlt es: `NONINTERACTIVE=1 brew install xcodegen` einmalig; scheitert das → Exit ≠ 0
6. `python3` vorhanden (Terminal-Profil)

### XCUI-Ausführung

Gleichwertig zur Norm (Ist-Implementierung):

1. `remote_dir` ist ein **Absolutpfad** auf dem Remote (kein `~` mehr im Invoke).
2. Testlauf in der **GUI-Session** des Console-Users via `open -a Terminal` auf eine Runner-`.command` (nicht `launchctl asuser` — Audit-Session unter SSH fehlt).
3. Runner setzt `DEVELOPER_DIR` aus Gate-Datei und `REISEN_MAC_UI_CODE_SIGNING_OFF=true`; Status nach `/tmp/reisen-macos-ui-run-<run-id>.exit`, Log/Command analog; Shell endet mit `exit 0`.
4. Wrapper setzt `CI` / `GITHUB_ACTIONS` **nicht**.
5. Kein AppleScript-`close` und kein `osascript` im Runner; Default-Profil wird unmittelbar nach `open` wiederhergestellt.
6. Exit 0 → Run-Dir remote löschen; Exit ≠ 0 → Run-Dir belassen (Pfad auf stderr).

## Fehlerbehandlung

| Fall | Verhalten |
| --- | --- |
| Host-Resolve: 0 Treffer oder &gt;1 Identity | Exit ≠ 0, Liste bzw. Remediation `REISEN_UI_REMOTE_HOST` |
| SSH/rsync fehlgeschlagen | Exit ≠ 0, kurze deutsche Meldung |
| `.git` fehlt | Exit ≠ 0 |
| Worktree-Quelle | Exit 0-Pfad; `.git` excluded; stderr loggt Worktree-Modus |
| Gate Xcode/console/xcodegen/PATH | Exit ≠ 0, konkrete Remediation (inkl. `xcode-select`) |
| UI-Test rot | Exit-Code von remote `macos-ui-test.sh`; Hinweis auf Log `${run-dir}/DerivedData/ReisenMacUITests/macos-ui-xcodebuild.log` und `/tmp/reisen-macos-ui-run-<run-id>.log` |
| Lock belegt | Warten bis 30 min; sonst Exit 73 |
| Attach/Signing | Remote: `REISEN_MAC_UI_CODE_SIGNING_OFF` in `macos-ui-test.sh` (unsigned build → Ad-hoc resign → test-without-building). Wrapper setzt `CI` nicht. |

## Einmalige Remote-Voraussetzungen (manuell)

1. Xcode **27** unter `/Applications` (`Xcode.app` oder `Xcode-beta.app`); First-Launch/License akzeptiert. Dauerhaftes `xcode-select` optional — der Wrapper setzt `DEVELOPER_DIR`.
2. Benutzer am iMac in der **entsperrten** GUI-Session eingeloggt (WindowServer; gesperrter Screen bricht XCUI oft ab)
3. TCC einmalig: Accessibility für **Xcode** / UI-Testing. Kein Automation-Dialog mehr für Terminal-Profil (kein `osascript`).
4. Homebrew unter `/opt/homebrew` (Apple Silicon) vorhanden
5. `python3` vorhanden (Terminal-Profil `ReisenUIRemote` schreiben/restoren)
6. SSH-Host-Key für den genutzten Host in `known_hosts` (sonst einmalig `REISEN_UI_REMOTE_STRICT_HOST_KEY=accept-new`)

## Doku-Updates (Implementierung)

- `AGENTS.md` — Zeile in der Kommando-Tabelle
- `.cursor/rules/reisen-macos-workflow.mdc` — Remote-Wrapper erwähnen
- Keine CI-YAML-Änderung

## Verifikation

1. `bash ./Scripts/macos-ui-test-remote.sh --self-test` — Resolve-Reihenfolge, Pflicht-Excludes, Quoting inkl. Selection-Passthrough, Lock-vor-Sync, Run-Dir-/tmp-Isolation
2. Bei erreichbarem Host + Xcode 27 + entsperrter GUI: `bash ./Scripts/macos-ui-test-remote.sh` → Exit 0 (Skip oder gefilterte Smokes), stderr zeigt Host + `run-id`; `--full` → volle `MacUISmokeTests`
3. Gate-Proben: zwei parallele Wrapper → zweiter wartet auf Lock; Sync-Ziel ist `${DIR}/<run-id>/` nicht der Maintainer-Checkout

## Folgespecs (bewusst später)

- Analoges `macos-ui-review-remote.sh`
- Optional: xcresult immer fetchen statt Opt-in
- Optional: Interface-Präferenz fest verdrahten (z. B. nur Ethernet-Subnet), falls RTT-Heuristik nicht reicht
- Optional: Worktree Common-Dir mitspiegeln (aktuell: `.git` exclude reicht für XCUI)
