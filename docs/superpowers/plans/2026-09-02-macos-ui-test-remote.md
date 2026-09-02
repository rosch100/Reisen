# macOS UI-Test Remote Host — Implementation Plan

> **For agentic workers:** Implement task-by-task; Spec-SSOT: `docs/superpowers/specs/2026-09-02-macos-ui-test-remote-design.md`.

**Goal:** Working-Tree-`rsync` + Remote-`macos-ui-test.sh` auf dem iMac (kein CI-Runner).

**Architecture:** Ein Wrapper `Scripts/macos-ui-test-remote.sh` resolved Host (altanis → Bonjour), spiegelt den Tree, gated Xcode≥27, startet XCUI via `launchctl asuser`.

**Tech Stack:** bash 3.2, ssh, rsync, dns-sd, ping, bestehende `macos-ui-test.sh`.

## Global Constraints

- bash 3.2 (`set -euo pipefail`), kein UTF-8-BOM, keine Associative Arrays
- Kein `CI=true` setzen; keine xcodebuild-Flag-Duplikation
- Worktree-`.git`-Datei → Fail-fast
- Secrets/PII-Excludes Pflicht

---

### Task 1: Wrapper-Script

**Files:** Create `Scripts/macos-ui-test-remote.sh`

- [x] Host-Resolve, rsync, Gates, `launchctl asuser`, optional xcresult-fetch
- [x] `--self-test` ohne Netz
- [x] `bash ./Scripts/macos-ui-test-remote.sh --self-test` → Exit 0

### Task 2: Doku

**Files:** Modify `AGENTS.md`, `.cursor/rules/reisen-macos-workflow.mdc`

- [x] Kommando-Zeile + Kurzhinweis Remote-Wrapper

### Task 3: Verifikation

- [x] Self-test grün
- [x] Remote-Lauf: Host-Resolve + Gate OK; aktuell Xcode/`xcode-select` auf iMac blockiert (Major unbekannt / CLT) — erwarteter Fail-fast bis Xcode 27 aktiv
