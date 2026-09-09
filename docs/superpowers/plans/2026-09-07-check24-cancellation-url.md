# Check24 Cancellation URL Implementation Plan

> **For agentic workers:** executing-plans / subagent-driven-development.

**Goal:** Persist Check24 `cancellationUrl` as booking detail + `?action=cancel`.

**Architecture:** `distinctURL` + builder in ReisenCheck24; set in `mapDraft`.

**Tech Stack:** Swift, Swift Testing

---

### Task 1

- [x] Builder + mapDraft + Policy + Tests + Docs
- [x] `bash ./Scripts/ci-test.sh`
