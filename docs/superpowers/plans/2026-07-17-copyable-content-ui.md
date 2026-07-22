# Copyable Content UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Inhaltliche UI-Texte (v. a. Fehlermeldungen) per Klick-Fokus, Selektion und CMD+C kopierbar machen.

**Architecture:** Gemeinsame `CopyableNSTextView`-Basis (Selektion → markierter Text, sonst `copyText`); SwiftUI-`CopyableTextView` / `CopyableLabel`; `SelectableBookingTextView` darauf umstellen; Sync-/Sheet-/Detail-Views verdrahten.

**Tech Stack:** SwiftUI, AppKit (`NSTextView`), macOS.

## Global Constraints

- Scope B: Inhaltsanzeigen ja, UI-Chrome/Buttons nein.
- Copy C + Fokus A: Klick → First Responder; Markierung oder ganzer `copyText`; nur Plain-Text.
- Icons nicht in die Zwischenablage.
- Keine Workarounds/Dummy-Werte; SSOT für Copy-Semantik.

---

### Task 1: CopyableNSTextView + CopyableTextView + CopyableLabel

**Files:**
- Create: `Sources/Reisen/App/CopyableTextView.swift`
- Modify: `Sources/Reisen/App/SelectableBookingTextView.swift`

- [x] **Step 1:** `CopyableNSTextView` mit `copyText`, `copy(_:)` / `writeSelection` (Selektion oder `copyText`; leer → kein Pasteboard-Write)
- [x] **Step 2:** `CopyableTextView` (plain text, Font/Color, Intrinsic Height)
- [x] **Step 3:** `CopyableLabel` (SF Symbol + `CopyableTextView`)
- [x] **Step 4:** `SelectableBookingNSTextView` von `CopyableNSTextView` ableiten; doppelte Copy-Logik entfernen

---

### Task 2: SyncView + StoreFailureView

**Files:**
- Modify: `Sources/Reisen/App/SyncView.swift`
- Modify: `Sources/Reisen/Reisen.swift` (`StoreFailureView`)

- [x] Fehler/Status/Keychain/missingProvider als `CopyableLabel`
- [x] `lastURLString` als `CopyableTextView`
- [x] Store-Failure-Message als `CopyableTextView`

---

### Task 3: Sheets + Trip-Detail-Inhalte

**Files:**
- Modify: `Sources/Reisen/App/AssignBookingsSheet.swift`
- Modify: `Sources/Reisen/App/TripEditorSheet.swift`
- Modify: `Sources/Reisen/App/TripDetailView.swift` (Notizen / sichtbare Inhaltswerte ohne Chrome)
- Modify: `Sources/Reisen/App/ContentView.swift` (offene Buchungen / Reise-Titel als Inhalt, keine Buttons)

- [x] `errorMessage` → `CopyableTextView`
- [x] Notizen und vergleichbare Detailtexte → `CopyableTextView`
- [x] Sidebar-Inhaltszeilen wo sinnvoll ohne Navigations-Buttons zu brechen

---

### Task 4: Verify

- [x] `swift build` (bzw. Package-Target Reisen)
- [ ] Manuell laut Spec-Checkliste (wenn Build grün)
