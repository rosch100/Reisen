# CI- und Agents-Infrastruktur für Reisen — Design Spec

> Ziel: Optimierte CI für das öffentliche SwiftPM-Projekt `rosch100/Reisen` inkl. „wichtiger Agents“ (Cursor/DevOps-Helfer), basierend auf GitHub-/Open-Source-Best-Practices.

## Kontext

Das Repo ist ein lokales SwiftPM-Projekt (macOS primär) ohne bestehende GitHub Actions / Workflows. Der relevante Build-/Testpfad ist über `swift build` und `swift test` (Swift Testing) sowie ein lokales App-Build-Skript `Scripts/build-app.sh`.

Wichtig: Die Package-Konfiguration setzt `.macOS(.v27)` in `Package.swift`. Daher muss die CI einen kompatiblen Runner/Xcode verwenden, sonst schlagen Build/Test fehl.

## Entscheidungen (fix)

1. **Platform/Runner:** macOS Runner `macos-26` und Xcode **26.x** gepinnt.
2. **Build/Test:** getrennt in „Build → Test“ innerhalb eines Jobs auf macOS (für klare CI-Zeitsignale und bessere Debuggability).
3. **Keine Linux-Tests:** kein Linux `swift test`, da AppKit/SwiftData/WebView-Integration erwartet wird.
4. **Signing/Notarize:** als „vorbereitetes, aber secrets-gegate“ Feature:
   - Release-Workflow produziert immer ein Artifact
   - Signing/Notarize läuft **nur**, wenn Apple-Secrets gesetzt sind
   - Bei fehlenden Secrets gibt es keinen stillen „Signed“-Fallback.
5. **Security/Quality:** CodeQL, OpenSSF Scorecard, Dependabot werden hinzugefügt.
   - Kern-CI („Build+Test“) bleibt das Pflicht-Gate.
   - Security-Workflows sind eigene Jobs/Workflows (können optional als Pflicht später ergänzt werden).

## Architektur (Workflows & Verantwortung)

Es werden **mehrere getrennte Workflows** eingeführt:

- `ci.yml`: PR-/Push-Checks (Build+Test)
- `codeql.yml`: CodeQL Scheduled + PR
- `scorecard.yml`: OpenSSF Scorecard
- `release.yml`: Tag-Releases `v*` und Signing/Notarize-Gating
- `dependabot.yml`: Updates für Actions (nur `github-actions`)

Zusätzlich werden Repo-Dateien ergänzt:

- `Scripts/ci-test.sh`: SSOT-Wrapper für `swift test`-Command in CI
- `Scripts/sign-and-notarize.sh`: Signing/Notarize Shell Helper
- `docs/ci/*`: Dokumentation (insb. Apple Secrets & Gate-Verhalten)
- `AGENTS.md` + Cursor-Regeln: „Agents“ definieren, die CI-/Review-/Security-Regeln kennen.

## Datenfluss (Execution Flow)

1. **PR/Pull Request:**
   - `ci.yml` führt `swift build --build-tests` aus
   - danach `swift test --skip-build` (gegen die gerade gebaute Testkonfiguration)
2. **Security (separat):**
   - CodeQL generiert/analysiert je nach Setup auf macOS
   - Scorecard bewertet Repository-Risiken
3. **Release (Tag `v*`):**
   - Build der `.app`/Artifact
   - Prüfung, ob Apple Signing/Notarize Secrets vorhanden sind
   - ggf. `sign-and-notarize.sh` ausführen

## Fehler- und Gate-Strategie

- Build/Test Fehler brechen CI sofort (kein `continue-on-error`).
- Signing/Notarize:
  - Wenn Secrets fehlen: Unsigned Pfad, aber Release bleibt erfolgreich
  - Wenn Secrets gesetzt sind und Signing/Notarize fehlschlägt: Release-Job fehlschlägt (um nicht in „falsch signiert“ oder „halb signiert“ zu enden).

## Verifikation (vor/ nach Umsetzung)

- Lokal: `./Scripts/ci-test.sh` muss grün sein.
- Remote: `ci` Workflow muss PR/Push zuverlässig durchlaufen.
- Release-Workflow:
  - `workflow_dispatch` ohne Apple Secrets → Unsigned Artifact vorhanden
  - Mit Secrets → Signing/Notarize durchgeführt

## Abgrenzungen (nicht im Scope)

- Keine Xcode Cloud Integration
- Kein Distribution-Automation in App Store Connect (nur Build/Artifact; Notarize/Stapelung, wenn Secrets gesetzt)
- Kein Linux basiertes Test-CI

