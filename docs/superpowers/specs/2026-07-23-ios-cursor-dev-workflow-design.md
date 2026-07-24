# iOS/iPadOS Cursor-Entwicklungsworkflow (Reisen)

## Ziel
Cursor soll die iOS/iPadOS-App zuverlässig **starten und debuggen** können — agent-autonom über Scripts (Build, Simulator, Logs), mit SweetPad/CodeLLDB für interaktives Debugging, und Xcode nur als Fallback für Signing/Entitlements/Instruments.

## Entscheidungen
| Thema | Wahl |
|-------|------|
| Primärziel | Agent-autonom (A) mit Xcode-Fallback (C) |
| Projektform | XcodeGen (`project.yml` als SSOT) |
| Generiertes `.xcodeproj` | Nicht committen; lokal/CI generieren |
| Bundle-ID | `de.roschmac.Reisen.ios` (getrennt von macOS `de.roschmac.Reisen`) |
| Default-Simulator | exakt `iPad Pro 13-inch (M5)` (überschreibbar via `IOS_SIMULATOR`) |

## Nicht-Ziele
- TestFlight/App-Store-Release-Pipeline für iOS
- Physisches Gerät als Default-Run-Target
- InjectionIII / Hot Reload
- Änderung der macOS-Build-Pipeline (`Scripts/build-app.sh`)

## Architektur

```text
Cursor (Edit + Agent)
    │
    ├─ SweetPad / CodeLLDB     → Build, Run, Breakpoints, Simulator
    ├─ Scripts/*.sh (SSOT)     → generate / run / test / logs (Agent + CI)
    └─ SourceKit via buildServer.json
            │
            ▼
    XcodeGen (project.yml) ──► .xcodeproj (gitignore, lokal generiert)
            │
            ▼
    xcodebuild + simctl        → iPad/iPhone Simulator
            │
            ▼
    Xcode GUI (Fallback)       → Signing, Entitlements, Instruments
```

### SSOT-Grenzen
- **App-Code:** `Apps/ReiseniOS` + Shared-Targets in `Package.swift`
- **Xcode-Projektform:** nur `project.yml` (kein committed `.xcodeproj`)
- **Build/Run/Test-Befehle:** Scripts unter `Scripts/` — Cursor-Tasks und (später) CI rufen dieselben Scripts auf
- **macOS-Pfad:** unverändert (`Scripts/build-app.sh`, executable `Reisen`)

## Komponenten

### XcodeGen (`project.yml`)
- Target `ReiseniOS`: `type: application`, platform iOS, Deployment Target ≥ 17
- Sources: `Apps/ReiseniOS`
- Dependencies: lokale Package-Produkte `ReisenAppCore`, `ReisenSharedUI` (Package-Root `.`)
- Info.plist unter `Apps/ReiseniOS/Info.plist` (Permissions analog macOS: Kalender, Reminders, Notifications)
- Scheme `ReiseniOS` (Build + Run; Test-Hook wenn Tests vorhanden)
- Signing: Automatic lokal; **keine** hardcodierte Team-ID in der Spec/Repo-Defaults

### Package.swift
- `ReiseniOS` als SPM-`executableTarget` / `.executable`-Product entfällt
- Shared Libraries bleiben SPM-SSOT
- Die iOS-**App** existiert nur als XcodeGen-Application-Target (vermeidet Doppel-Einstiegspunkt „executable ≠ App-Bundle“)

### Scripts (SSOT)
| Script | Zweck |
|--------|--------|
| `Scripts/generate-ios-project.sh` | Prüft XcodeGen, erzeugt `.xcodeproj` |
| `Scripts/ios-run.sh` | Generate → Build → Boot Simulator → Install/Launch |
| `Scripts/ios-test.sh` | Generate → `xcodebuild test` (wenn Tests vorhanden) |

Umgebung:
- `IOS_SIMULATOR` (Default: exakt `iPad Pro 13-inch (M5)`)
- Keine stillen Simulator-Fallbacks: fehlt genau dieser Name → Exit ≠ 0 und Liste verfügbarer Geräte (Aufrufer setzt dann `IOS_SIMULATOR` bewusst)

### Cursor-Tooling
- Empfohlene Extensions: SweetPad, CodeLLDB, Swift (offiziell) via `.vscode/extensions.json`
- `.vscode/tasks.json` ruft die Scripts auf
- `.vscode/launch.json` für SweetPad/LLDB-Debug
- `buildServer.json` via SweetPad generieren (nicht committen bzw. regenerierbar)
- Agent-Regel: iOS Build/Run nur über die Scripts — kein ad-hoc-`xcodebuild` mit losen Flags im Standard-Workflow

### Gitignore
Erweitern um generierte Artefakte, u. a.:
- `*.xcodeproj/`
- generierte Workspaces (außer bewusst gewollte Ausnahmen)
- `buildServer.json`
- ggf. `.sweetpad/`
- bestehende Einträge (`DerivedData/`, `xcuserdata/`, `.build`) bleiben

## Workflow

### Täglicher Loop
1. Repo öffnen → bei Bedarf `bash ./Scripts/generate-ios-project.sh`
2. Code in Cursor ändern
3. Start/Debug:
   - Mensch: SweetPad Build & Run / LLDB (F5)
   - Agent: `bash ./Scripts/ios-run.sh`
4. Bei Fehlern: Build-/Simulator-Logs lesen → fixen → Script erneut
5. Fallback: generiertes `.xcodeproj` in Xcode für Signing, Entitlements, Instruments

### Agent-Kontrakt
- Build/Run/Test ausschließlich über die Scripts
- Exit-Code ≠ 0 = Fehler (keine Dummy-Erfolge, keine stillen Ersatz-Simulatoren)
- Simulator per Env/Flag überschreibbar
- Kein Commit generierter Xcode-Artefakte

### Rollenmatrix
| Aktion | Werkzeug |
|--------|----------|
| Edit + AI | Cursor |
| Run + Breakpoints | SweetPad + CodeLLDB |
| Schnell-Check ohne Debugger | `ios-run.sh` |
| Provisioning / Capabilities | Xcode GUI |
| CI-Anbindung der Scripts | Späterer Schritt (nicht Pflicht in v1 dieses Designs) |

## Fehlerbehandlung
| Situation | Verhalten |
|-----------|-----------|
| XcodeGen fehlt | Abbruch mit Install-Hinweis (`brew install xcodegen`) |
| Generate fehlschlägt | Exit ≠ 0, stderr behalten |
| Kein passender Simulator | Exit ≠ 0; verfügbare Geräte auflisten |
| Build fehlschlägt | `xcodebuild`-Log ausgeben (optional `xcbeautify`); nicht verschlucken |
| App startet nicht | Launch-Fehler + relevante Simulator-Logs; kein Erfolg vortäuschen |
| SweetPad/LLDB defekt | Script-Pfad bleibt gültig; Xcode-Fallback nutzen |

## Verifikation (Definition of Done)
1. `bash ./Scripts/generate-ios-project.sh` erzeugt ein öffnungsfähiges `.xcodeproj`
2. `bash ./Scripts/ios-run.sh` startet die App auf dem Default-iPad-Simulator
3. In Cursor trifft ein Breakpoint in `ReiseniOSApp` (SweetPad + CodeLLDB)
4. Änderung in einem Shared-Modul (z. B. `ReisenAppCore`) baut über denselben Pfad mit
5. `git status` zeigt keine versehentlich getrackten `.xcodeproj` / `buildServer.json`

## Doku
- Kurzleitfaden: `docs/dev/ios-cursor.md` (Setup: XcodeGen, Extensions, Scripts, SweetPad einmalig, Xcode-Fallback)
- Optionaler Verweis aus `README.md`

## Bezug zur App-Spec
Funktionale iOS/iPadOS-UI und Parität sind in `docs/superpowers/specs/2026-07-23-ios-ipados-universal-design.md` beschrieben. Dieses Dokument spezifiziert nur den **Entwicklungs- und Debug-Prozess** in Cursor.
