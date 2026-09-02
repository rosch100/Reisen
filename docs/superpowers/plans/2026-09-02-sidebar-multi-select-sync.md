# Sidebar Multi-Select Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sidebar und mittlere Listen synchron mehrfach auswählen; Selection-Kontextmenü inkl. Batch-Löschen für Reisen, offene und abgelaufene Buchungen sowie Trip-Buchungen.

**Architecture:** Selection-SSOT in `ContentView`-Sets; Mitte native `List(selection:)`; Sidebar OutlineMultiSelect; Menu-Effective-Set (Context-Target, keine Builder-Mutation); AppCore Batch-Orchestrator; App-Handler Units als Entry-Handoff-Evidence; AX `isSelected`; Diagnostics.

**Tech Stack:** SwiftUI macOS, AppKit modifier flags, SwiftData, ReisenAppCore, ReisenSharedUI, ReisenDiagnostics, XCUI ReisenMacUITests.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-02-sidebar-multi-select-sync-design.md`
- Jede `entry`-Änderung liefert Evidence-Test **im selben Task**
- Batch-Handoff: Handler-Unit mit Fake-Deleter (kein XCUI Confirm-Tap)
- Seed ≥2 Open, ≥2 Trip-Bookings, ≥2 Trips
- Agents UI: `bash ./Scripts/macos-ui-test-remote.sh`
- Isolation-Grep vollständig; keine neuen Defaults-Sites

---

### Task 1: OutlineMultiSelect + MenuEffectiveSelection (TDD)

**Files:** `OutlineMultiSelect.swift`, `MenuEffectiveSelection.swift` + AppCoreTests

- [ ] **Step 1: RED tests** (replace/toggle/range/anchor; MenuEffective)
- [ ] **Step 2: Implement GREEN**
- [ ] **Step 3: Commit** `feat: OutlineMultiSelect and MenuEffectiveSelection`

---

### Task 2: Context-Action SSOT Batch Delete (TDD)

**Files:** `TripTimelineContextActions.swift`, `SidebarEntryContextActions.swift` + SharedUITests

- [ ] **Step 1: RED → GREEN → Commit** `feat: batch delete in selection context action SSOT`

---

### Task 3: Orchestrator + Diagnostics + Confirm-Handlers (TDD)

**Files (alle ReisenAppCore — testbar ohne App-Target):**
- `SelectionBatchDeletion.swift`
- `SelectionBatchDeleteDiagnostics.swift` (oder Erweiterung bestehender Diagnostics)
- `SelectionBatchDeleteHandlers.swift` — Free Functions mit `deleteOne: (ID) throws -> Void` / Trip-Policy
- Tests in `Tests/ReisenAppCoreTests/`

- [ ] **Step 1: RED orchestrator + handler tests**
- [ ] **Step 2: Implement GREEN**
- [ ] **Step 3: Commit** `feat: batch delete orchestrator handlers and diagnostics`

---

### Task 4: Product Wiring + XCUI Entries + Seed (ein Task)

**Files:**
- `ContentView.swift`, `TripDetailView.swift`, `TripMultiSelectionSummary.swift`, Identifiers, `UITestingSeed`, MacUI/MacUISmokeTests
- Wire Confirm buttons → Task-3-Handlers
- AX `isSelected` on outline rows
- XCUI: Open sync ⌘; Menu-Effective (Multi = kein Copy; Singleton Effective = Copy Existence); Trip multi Summary; Timeline multi menu reach
- Isolation-Grep full; `ci-build`, `macos-ui-test-remote`, `ci-test`

- [ ] **Step 1: Wire UI to handlers**
- [ ] **Step 2: XCUI Pflicht-Entries (selber Task)**
- [ ] **Step 3: Isolation-Grep + builds/tests**
- [ ] **Step 4: Commit** `feat: sync multi-select UI with XCUI selection evidence`

---

## Self-Review

- Entry+Evidence same task (Task 3 handlers, Task 4 XCUI+wire)
- Context-Target documented
- Menu-Effective XCUI uses differentiable items
- No Confirm-Tap in Smoke
