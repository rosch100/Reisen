# Menu Action Labels HIG Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or implement task-by-task). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Alle `action.*` / `menu.*` / Editor-Titel-Labels laut Spec `2026-09-02-menu-action-labels-hig-design.md` vereinheitlichen.

**Architecture:** Nur sichtbare Strings in `Localizable.xcstrings` (DE/EN); keine Key-Renames. Tests/XCUI-Titel-Reach und Kommentare an neue Wortlaute anpassen.

**Tech Stack:** Swift / String Catalog (`Localizable.xcstrings`), Swift Testing, XCUI (macOS).

## Global Constraints

- Spec-SSOT: `docs/superpowers/specs/2026-09-02-menu-action-labels-hig-design.md` (approved, Ansatz A)
- Kein Key-Rename; Help-/Status-Keys out-of-scope
- Ellipsis nur laut Spec-Tabelle
- EN Title Case für Menü-/Action-Titel; Editor-Titel ebenfalls Title Case
- Asserts nicht schwächen; Identifier-basierte Tests unverändert lassen
- Isolation: Git-Worktree; nicht auf dirtyem Default-Checkout arbeiten

---

## Task 1: xcstrings auf Spec-Tabelle setzen

**Files:**
- Modify: `Sources/ReisenDomain/Resources/Localizable.xcstrings`

- [x] Script/Python: alle Spec-Keys DE/EN/`…` setzen (inkl. Ellipsis-Zeichen `…`)
- [x] `editor.create_title` EN → `New Booking`; übrige Tabelle 1:1
- [x] Out-of-scope-Keys unberührt lassen
- [x] Commit: `i18n: HIG-konforme Menü-/Aktionslabels`

## Task 2: Code-Kommentare / Hardcoded-Titel in Tests

**Files:**
- Modify: Tests mit Literal „Buchung hinzufügen“, „Neue Reise anlegen“, „Neue Reise erstellen“, „Remove from trip“, DE-Menütitel
- Modify: `Sources/ReisenSharedUI/CreateTripFromBookingsLabel.swift` Kommentar
- Modify: ggf. `UITestingIdentifiers` nur wenn Titel-Konstanten existieren (z. B. `removeFromTripMenuTitleDE`)

- [x] `rg` nach alten Literalen; auf Spec-Wortlaut aktualisieren
- [x] Commit: `test: Menü-Titel-Reach an HIG-Labels anpassen`

## Task 3: Verifikation

- [x] `bash ./Scripts/ci-test.sh`
- [x] `bash ./Scripts/ci-build.sh --arch arm64`
- [x] Bei UI-Titel-Diff: `bash ./Scripts/macos-ui-test-remote.sh` (iMac; lokal nur nach Remote-Ausfall)
- [x] Kurz Ellipsis-Stichprobe: `menu.add_booking` hat `…`, `action.add_booking` nicht

## Task 4: Ship

- [ ] PR gegen `master`, CI, Merge laut Repo-Workflow
