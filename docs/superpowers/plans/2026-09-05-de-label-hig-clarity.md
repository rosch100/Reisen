# DE-Bezeichner HIG / Klartext — Implementation Plan

> **For agentic workers:** Spec: `docs/superpowers/specs/2026-09-05-de-label-hig-clarity-design.md`

**Goal:** Nutzer-sichtbare Labels ohne Slash-Komposita und Wortstummel; Sync-Hybrid.

**Architecture:** Nur `Localizable.xcstrings` + sichtbare Literal-Spiegel. Keine Key-Renames.

**Tech Stack:** String Catalog, Swift Testing, `Scripts/ci-test.sh`, `Scripts/macos-ui-test-remote.sh`

## Global Constraints

- Scope A: sichtbare Copy; Sync-Hybrid 3
- Suspensionsstrich „und -ende“ erlaubt; `/-` verboten
- Commit nur auf User-Anweisung

## Tabellen

SSOT-Tabellen A–D: Spec `2026-09-05-de-label-hig-clarity-design.md` (dort vollständig).

## Tasks

- [x] Spec schreiben (inkl. Tabellen A–D)
- [x] Catalog A/B + UITestingIdentifiers + Kommentare + L10nTests
- [x] Catalog C
- [x] `ci-test.sh` + `macos-ui-test-remote.sh`
- [x] Conformity-Remediation: Spec-Tabellen, Sync-Hybrid-Asserts, Editor-Spec-Zeile
