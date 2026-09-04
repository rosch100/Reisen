# DE-Copy-Klarheit Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sichtbare DE/EN-Copy laut Spec `docs/superpowers/specs/2026-09-04-de-copy-clarity-design.md` im String Catalog angleichen.

**Architecture:** Nur `Localizable.xcstrings` (+ betroffene String-Asserts) und Editor-UI ohne Offset-Felder. Keine Key-Renames.

**Tech Stack:** String Catalog JSON, SwiftUI Editor, Swift Testing, `Scripts/ci-test.sh`

## Global Constraints

- Spec-Tabelle A–F exakt; Offsets sind **Nicht-UI**.
- Trips-Plural „Reisen“ und Kalender-Titel „Reisen“ nicht zu Voyenna machen.
- `git diff --check` sauber.

---

### Task 1: Catalog + Baggage-Tests

**Files:**
- Modify: `Sources/ReisenDomain/Resources/Localizable.xcstrings`
- Modify: `Tests/ReisenDomainTests/BaggageInfoFormatterTests.swift`
- Modify: `Tests/ReisenDomainTests/L10nTests.swift`

- [x] **Step 1:** Alle Spec-Werte A–F in `Localizable.xcstrings` setzen (`state: translated`).
- [x] **Step 2:** `BaggageInfoFormatterTests` von Literal `Pax` auf `Passagier` / L10n umstellen.
- [x] **Step 3:** `bash ./Scripts/ci-test.sh` grün.
- [ ] **Step 4:** Commit nur auf explizite User-Anweisung.

### Task 2: Offset-Felder aus Editor entfernen

**Files:**
- Modify: `Sources/ReisenSharedUI/BookingEditor.swift`
- Modify: `Tests/ReisenSharedUITests/BookingEditorValidationTests.swift`
- Modify: `docs/superpowers/specs/2026-09-04-de-copy-clarity-design.md`

- [x] **Step 1:** Hotel-/Flug-/Storno-Offset-`TextField`s entfernen; Werte still round-trippen.
- [x] **Step 2:** Offset-Validierung und Focus-Cases entfernen.
- [x] **Step 3:** Test + `ci-test.sh` grün.
- [x] **Step 4:** XCUI bewusst entbehrlich (reine Copy/Editor-Feld-Entfernung; Identifier-Smokes unberührt; Nutzer: nicht nötig).
