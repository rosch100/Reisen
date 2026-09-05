# App Semantik-Audit R15 Implementation Plan

> Spec: `docs/superpowers/specs/2026-09-05-app-semantics-audit-r15-design.md`

**Branch:** `audit/app-semantics-2026-09-05-r15`
**Finding:** `r15-editor-gmt-anchor-datepicker-load`

## Tasks

1. [x] `HotelStayDatePicker.localPickerDate(fromStored:)` + Forwarding `HotelStayDateStored` / `HotelStayDate`
2. [x] `TripEditorSheet` Load: Trip + Seed via `localPickerDate`
3. [x] `BookingEditorDraft.fromDomain`: Hotel-Daten konvertieren; Instant-Typen nicht
4. [x] `BookingEditorDraft.createDefault`: Trip-/Gap-Prefill via `localPickerDate`
5. [x] `HotelStayDateTests`: Round-Trip LA/Berlin + West-of-GMT No-Shift
6. [x] Prefill-/createDefault-Tests
7. [x] Spec/Plan
8. [ ] `bash ./Scripts/ci-test.sh` / Codereview / PR (Parent)
