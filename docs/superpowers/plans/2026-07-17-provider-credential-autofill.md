# Provider Credential Autofill (Ansatz 3) — Implementation Plan

> **For agentic workers:** Implement UX polish against the freigegebene Spec; Kernlogik ist bereits vorhanden.

**Goal:** Ansatz 3 als klarer Primärweg (Konto speichern + Auswahl + Ausfüllen); Texte/Buttons darauf ausrichten.

**Spec:** `docs/superpowers/specs/2026-07-17-provider-credential-autofill-design.md`

## Tasks

### Task 1: UX-Texte & Button-Priorität

- `KeychainCredentialStore.CredentialStoreError.noEntry`: Primär „Konto speichern…“, Keychain Access nur Nebenweg.
- `SyncView` Status-/Hilfetexte und Button-Reihenfolge angleichen.
- `SaveProviderCredentialSheet`: klarer Ablauf + Button „Passwords öffnen“.

### Task 2: Verify

- `swift build --target Reisen`
- `swift test --filter ReisenProvidersTests` und Domain-Keys-Tests
