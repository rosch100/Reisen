# Booking.com Hotel Cancellation URL Implementation Plan

> **For agentic workers:** executing-plans.

**Goal:** Persist hotel `cancellationUrl` by mapping confirmation→cancel while keeping `auth_key`.

**Architecture:** `distinctURL` for `.hotel` only; builder in ReisenBookingCom; set in GraphQL draft mapper.

---

### Task 1

- [x] Builder + mapper + policy + tests + docs
- [x] `bash ./Scripts/ci-test.sh`
