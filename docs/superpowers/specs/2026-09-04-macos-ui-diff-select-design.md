# macOS XCUI: Diff-Selektion lokal / Full on demand

**Datum:** 2026-09-04
**Status:** freigegeben (Spec-Review OK; Conformity Rev 1–3 eingearbeitet; Implementierung verdrahtet)
**Abhängigkeit:** [`2026-08-30-macos-ui-surface-test-design.md`](2026-08-30-macos-ui-surface-test-design.md) (Testvertrag), [`2026-09-02-macos-ui-test-remote-design.md`](2026-09-02-macos-ui-test-remote-design.md) (Remote-Transport; Rev 7 Flag-Passthrough)

## Änderungsprotokoll

### Rev 1 — Conformity

- Selektion **nur lokal** (Git-Working-Tree); Remote erhält fertige Args — Worktrees ohne `.git` auf dem iMac.
- Remote-Spec-Rev 7 als Pflicht-Deliverable (argv-Passthrough).
- Hunk→Methode: Zeilen-Span-Overlap-Algorithmus.
- Python-Tests: `test_ci_macos_ui_select_tests.py` (Discover-Pattern `test_ci_*.py`).
- Skip: verpflichtende stderr-Zeile inkl. DoD-Hinweis.

### Rev 2 — Conformity Fix (Implementierung)

- `+`-Leerzeilen zählen nicht als Overlap (Einfügen zwischen Methoden).
- Shell-Wiring: `macos-ui-test.sh` / `macos-ui-test-remote.sh` Modes + Docs/Rules/Skill Sync.

### Rev 3 — Shell-Härtung (Port aus #152-Follow-up)

- **SKIP_STDERR SSOT:** Shell liest `SKIP_STDERR` fail-closed aus `macos_ui_select_tests.py` (kein duplizierter Shell-String).
- **Skip-Sentinel:** leere Selection → intern `return 10` in Resolve-Helfern → Prozess-Exit 0 (unterscheidbar von Python-/Git-Fehlern).
- **Diff-Basis:** ein `git diff <basis> -- MacUISmokeTests.swift` (staged + unstaged); untracked-neu via `git cat-file -e <basis>:path`.
- **Self-Test:** `--self-test` nur als alleiniges argv; hermetischer Empty-Diff via Temp-Repo + `REISEN_MAC_UI_REPO_ROOT`.
- **Remote:** `reisen_ui_remote_resolve_test_args` vor Lock/Host/Sync; `reisen_ui_remote_quote_test_invoke` + `${test_invoke}` in `.command`.

## Ziel

Lokale und Agent-XCUI-Läufe (`macos-ui-test.sh` / Remote-Wrapper) sollen **primär nur die durch den Diff berührten Smoke-Tests** ausführen. Die **vollständige** `MacUISmokeTests`-Klasse bleibt **on demand** (`--full`) und in **CI** unverändert Pflicht.

## Nicht-Ziele

- Kein Path→Test-Manifest und keine XCTest-Tags / `.xctestplan`
- Keine Änderung der CI-Suite-Selection (`ci-select-suites.py` Job on/off)
- Kein Diff-Filter für `macos-ui-review.sh` (advisory Tour bleibt separat)
- Keine iOS-XCUI-Selektion in diesem Spec
- Keine Git-Operationen auf dem Remote-Host für Test-Selektion

## Entscheidungen

| Thema | Wahl |
| --- | --- |
| Selektion | Diff-basiert: hinzugefügte/geänderte `func test…` in `MacUISmokeTests.swift` (Ansatz 1) |
| Wo läuft Selektion | **Immer lokal** im Dev-Checkout / Worktree (`macos_ui_select_tests.py`); nie remote |
| Kein Treffer | Kein `xcodebuild test`, verpflichtende stderr-Meldung, **Exit 0** |
| Lokal / Agents Default | Diff-Selektion |
| Full on demand | `--full` → ganze Klasse `MacUISmokeTests` |
| CI | Immer Full (`CI`/`GITHUB_ACTIONS` in `macos-ui-test.sh`, auch ohne `--full`) |
| Remote | Leitet **exakte** Test-Args durch (`--full` und/oder `-only-testing:…`); keine eigene Diff-Logik |
| Diff-Basis | `merge-base(HEAD, origin/master\|master)` + Working Tree (staged/unstaged via `git diff <base> -- MacUISmokeTests.swift`); Override `--diff-base` (CLI) vor `REISEN_MAC_UI_DIFF_BASE` (Env) |
| Parser-/Diff-Fehler | Fail-closed, Exit ≠ 0, klare Meldung — **kein** stilles Full |

## Architektur

```text
Lokal (Dev-Mac / Agent-Worktree)
────────────────────────────────
macos-ui-test.sh [--full]
  ├─ CI / --full ──► xcodebuild … -only-testing:…/MacUISmokeTests
  └─ Default ──► macos_ui_select_tests.py  (git lokal)
                    ├─ Treffer ──► xcodebuild … + je -only-testing:…/testName
                    └─ leer ──► stderr Skip+DoD, Exit 0 (kein xcodebuild)

macos-ui-test-remote.sh [--full]
  1. lokal: dieselbe Selection wie oben (oder --full / CI-N/A remote)
  2. bei Skip lokal: Exit 0, kein rsync/Test
  3. sonst: rsync Working Tree → iMac
  4. remote: macos-ui-test.sh --reisen-ui-only-testing <args…>
     bzw. --full  (keine erneute Diff-Selektion remote)
```

`REISEN_MAC_UI_CODE_SIGNING_OFF` bleibt Remote-Signing; wird **nicht** mit Selection vermischt. Remote setzt `CI` nicht → Full nur bei explizitem `--full` vom Wrapper.

## Selektion (SSOT)

### Eingabe

- **v1-Pfad:** nur `Tests/ReisenMacUITests/MacUISmokeTests.swift` (nicht `MacUIReviewTourTests`).
- Diff relativ zur Diff-Basis (siehe Entscheidungen), **im lokalen Repo**.
- Working Tree: `git diff <basis> -- MacUISmokeTests.swift` (staged und unstaged gegen die Basis).

### Algorithmus (Hunk → Methode)

1. Aktuellen Dateiinhalt von `MacUISmokeTests.swift` lesen (Working-Tree-Version).
2. Methoden-Spans: jede Zeile `^\s*func (test[A-Za-z0-9_]*)\s*\(` startet eine Methode; Span endet vor der nächsten solchen Zeile bzw. vor dem schließenden Klassen-`}` auf Indent-0 der Klasse (praktisch: bis zur nächsten `func test` oder EOF der Klasse). Nur `test*`-Methoden; `setUp`/`tearDown` erzeugen keine Spans für Selection.
3. Unified Diff gegen Basis: alle geänderten Zeilennummern der **neuen** Dateiseite (`+`-Hunks / Context-Mapping auf Working-Tree-Zeilen). Reine Leerzeilen auf der `+`-Seite zählen **nicht** als Overlap (sonst würde Einfügen zwischen Methoden die vorherige `test*`-Methode selektieren).
4. Eine Methode ist selektiert, wenn ihr Span mindestens eine geänderte Working-Tree-Zeile überlappt **oder** die Methode im Diff als neu eingeführt gilt (`+`-Zeile mit `func test…`).
5. Gelöschte Methoden (nur `-`-Seite, kein Span mehr in Working Tree) → nicht selektieren.
6. Datei komplett neu → alle `test*`-Spans der Working-Tree-Datei.
7. Keine Overlaps → leere Selection.

### Regeln (Kurz)

1. Overlap/Neu → Selection (Algorithmus oben).
2. Gelöscht → nicht selektieren.
3. Nur Helper / kein `test*`-Overlap → Skip/Exit 0.
4. **Selector-I/O:** stdout = eine `-only-testing:ReisenMacUITests/MacUISmokeTests/<testName>`-Zeile pro Treffer; leere stdout + Exit 0 = Skip; Exit ≠ 0 = Fehler (kein Full).
5. **Skip-Stderr (Pflicht):** Konstante `SKIP_STDERR` in `macos_ui_select_tests.py`; Shell druckt sie via Import (fail-closed). Form:
   `macos-ui-test: no smoke selection (diff); skip XCUI. DoD: UI-Verhalten erfordert Smoke-Edit in MacUISmokeTests.`

### CLI / Env

| Flag / Env | Wirkung |
| --- | --- |
| (Default, nicht CI) | Diff-Selektion lokal |
| `--full` | Ganze `MacUISmokeTests` |
| `--reisen-ui-only-testing` + Args | Vorgegebene `-only-testing:…`-Liste nutzen; **keine** Diff-Selektion (Remote-Pfad) |
| `CI=true` / `GITHUB_ACTIONS=true` | Immer Full (auch ohne `--full`) |
| `REISEN_MAC_UI_DIFF_BASE` | Explizite Git-Ref/Commit als Diff-Basis statt Merge-Base (nach `--diff-base`) |
| `--diff-base` | CLI-Override der Diff-Basis; hat Vorrang vor `REISEN_MAC_UI_DIFF_BASE` |

## Komponenten

| Artefakt | Rolle |
| --- | --- |
| `Scripts/macos_ui_select_tests.py` | Lokaler Diff → stdout `-only-testing`-Zeilen; Skip/Fehler wie Regeln 4–5 |
| `Scripts/tests/test_ci_macos_ui_select_tests.py` | Fixture-Diffs: add/modify/delete/empty/error (Discover via `ci-test.sh` `test_ci_*.py`) |
| `Scripts/macos-ui-test.sh` | Selector lokal; `--full`; CI-Full; `--reisen-ui-only-testing` |
| `Scripts/macos-ui-test-remote.sh` | Lokal select/skip/`--full`, dann Passthrough an Remote-Invoke |
| `docs/superpowers/specs/2026-09-02-macos-ui-test-remote-design.md` | Rev 7: argv-Passthrough (Pflicht mit diesem Spec) |
| Docs/Rules (`AGENTS.md`, `reisen-macos-workflow.mdc`, Observability-Skill) | Agents: Default Remote **ohne** `--full`; `--full` on demand; Skip-Stderr beachten |

## Agent- und DoD-Vertrag

- Bei UI-/Smoke-relevanten Features/Bugfixes bleiben Identifier + angepasste/neue Smoke-Methoden Pflicht.
- Agent-Default: `macos-ui-test-remote.sh` ohne `--full` → lokale Diff-Selektion, bei Treffern Remote nur diese Tests.
- Fehlt ein Smoke-Edit trotz UI-Diff → lokaler Skip (Exit 0) + Skip-Stderr; **DoD nicht erfüllt**, bis Smoke existiert; **CI Full** bleibt zusätzliches Sicherheitsnetz.
- Expliziter Full-Lauf: `bash ./Scripts/macos-ui-test-remote.sh --full` (lokal nur nach nachgewiesenem Remote-Ausfall).

## Verifikation

- `python3 -m unittest discover -s Scripts/tests -p 'test_ci_*.py'` deckt Selector ab (`test_ci_macos_ui_select_tests.py`).
- Shell-`--self-test` (nur alleiniges argv): `--full`, Skip-Stderr aus Python, `--reisen-ui-only-testing`, hermetischer Empty-Diff (`REISEN_MAC_UI_REPO_ROOT`), Remote-Passthrough + Resolve-vor-Lock (kein Git auf Remote nötig).
- CI-Job `suite-macos-ui` weiterhin Full-Klasse (Regression der Gate-Semantik).

## Abgrenzung zu bestehendem Spec

- Remote-Spec: Transport/Lock/Signing **plus** Rev-7-Passthrough der vom Lokalrechner berechneten Test-Args; keine Diff-Selektion remote.
- Surface-Test-Design (Identifier, Page Object, Existence-only) unverändert.
