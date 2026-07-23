# iOS/iPadOS-Entwicklung in Cursor

Kurzleitfaden für Build, Run, Test und Debug der iOS-App **ReiseniOS** aus Cursor heraus. Die Scripts unter `Scripts/` sind SSOT — Cursor-Tasks und Agent-Workflows rufen dieselben Befehle auf.

Design-Spec: [2026-07-23-ios-cursor-dev-workflow-design.md](../superpowers/specs/2026-07-23-ios-cursor-dev-workflow-design.md)

## Voraussetzungen

- **Xcode** (aktuelle Version mit iOS-Simulator)
- **XcodeGen:** `brew install xcodegen`
- **Empfohlene Cursor/VS-Code-Extensions** (siehe `.vscode/extensions.json`):
  - [SweetPad](https://marketplace.visualstudio.com/items?itemName=sweetpad.sweetpad) — Build, Run, Simulator
  - [CodeLLDB](https://marketplace.visualstudio.com/items?itemName=vadimcn.vscode-lldb) — LLDB-Debugging
  - [Swift (offiziell)](https://marketplace.visualstudio.com/items?itemName=swiftlang.swift-vscode) — SourceKit, Syntax

Beim ersten Öffnen des Repos Cursor die empfohlenen Extensions installieren lassen.

## Erstmaliges Setup

1. Repo in Cursor öffnen.
2. Xcode-Projekt generieren:

```bash
bash ./Scripts/generate-ios-project.sh
```

Das erzeugt lokal `Reisen.xcodeproj` aus `project.yml` (nicht committen).

## Agent / CLI: Run und Test

| Aktion | Befehl |
|--------|--------|
| App auf Simulator starten | `bash ./Scripts/ios-run.sh` |
| Unit-Tests auf Simulator | `bash ./Scripts/ios-test.sh` |
| Nur Projekt generieren | `bash ./Scripts/generate-ios-project.sh` |

**Default-Simulator:** exakt `iPad Pro 13-inch (M5)`.

Anderen Simulator wählen (kein stiller Fallback — fehlt der Name, bricht das Script ab und listet verfügbare Geräte):

```bash
IOS_SIMULATOR="iPhone 16" bash ./Scripts/ios-run.sh
```

Entsprechende Cursor-Tasks: **Terminal → Run Task…** → `iOS: Generate Xcode project`, `iOS: Run on Simulator`, `iOS: Test on Simulator`.

## Menschliches Debug: SweetPad + F5

1. Einmalig: Command Palette → **SweetPad: Generate Build Server Config**  
   → erzeugt `buildServer.json` im Repo-Root (gitignored, nicht committen).
2. Breakpoint setzen, z. B. in `Apps/ReiseniOS/ReiseniOS.swift` (`ReiseniOSApp`-Body).
3. **F5** oder Launch-Konfiguration **Attach to running app (SweetPad)** — startet vorher die SweetPad-Launch-Task (`ReiseniOS`, Debug).
4. Alternativ: SweetPad-Sidebar → Build & Run für Scheme `ReiseniOS`.

LLDB-Pfad ist in `.vscode/settings.json` auf das Xcode-Framework gesetzt. `sweetpad.xcodegen.autoGenerate` ruft bei Bedarf `generate-ios-project.sh` auf.

## Xcode-Fallback

Generiertes Projekt in Xcode öffnen:

```bash
open Reisen.xcodeproj
```

Nutzen für **Signing**, **Entitlements**, **Capabilities** und **Instruments** — nicht als primärer Edit-/Build-Pfad in Cursor.

## Git-Hygiene

Nicht committen (siehe `.gitignore`):

- `*.xcodeproj/`
- `buildServer.json`
- `.sweetpad/`
- `DerivedData/`

Vor Push: `git status` prüfen — keine generierten Xcode-Artefakte im Index.
