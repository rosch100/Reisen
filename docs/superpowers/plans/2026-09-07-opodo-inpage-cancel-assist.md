# Opodo In-Page Cancel Assist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or subagent-driven-development.

**Goal:** Opodo Stornieren opens trip details and Assist surfaces the cancel confirm dialog without auto-confirming.

**Architecture:** `inPageOnOpen` + `cancellationUrl == externalUrl`; one-shot `OpodoCancelAssist` clicks only the entry control; never „Diese Buchung stornieren“.

**Tech Stack:** Swift, WKWebView, Swift Testing, DiagnosticLogger

## Global Constraints

- Reisen storniert nicht selbst; Assist storniert nicht.
- Keine Tokens/PII in Logs.
- `bash ./Scripts/ci-test.sh`; kein XCUI.

---

### Task 1: Policy + Catalog + Assist + Sheets + Docs

- [x] Policy/Catalog/tests
- [x] OpodoCancelAssist (+ Script/Runner) + Cancel-Sheet wire
- [x] Docs matrix
- [x] `ci-test.sh`
