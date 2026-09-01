<!--
  Copilot Code Review Instructions (Reisen)

  Hinweis: Diese Datei beeinflusst Reviews, die über Copilot Code Review
  (oder ähnliche GitHub-Integrationen) generiert werden.
-->

# Copilot Code Review Instructions

## Zweck
- Finde echte Fehler, Sicherheitsrisiken, logische Inkonsistenzen und Breaking-Änderungen.
- Gib konkrete, nachvollziehbare Verbesserungsvorschläge.

## Fokus (erwünscht)
- Korrektheit: Annahmen, Edge Cases, Off-by-one, falsche Conditions.
- Security: Secrets, Injection, unsichere Deserialisierung/Parsing, gefährliche Permissions.
- Wartbarkeit: klare Verantwortlichkeiten, sinnvolle Abstraktionen, keine redundant duplizierte Logik.
- Verhaltensänderung ohne Tests und/oder ohne `DiagnosticLogger`-Events (siehe `.cursor/rules/reisen-logging-and-tests.mdc`).
- Schichtverletzung (Domain mit SwiftData/WebKit, UI schreibt Persistenz direkt) — `docs/ARCHITECTURE.md`.

## Was wir vermeiden (nicht priorisieren)
- Style-/Format-/Lint-Nits ohne fachliche Auswirkung.
- Mehrzeilige „AI-Kommentare“ zu einzelnen Codezeilen ohne tatsächliche Begründung.

## Kommentarformat
- Starte Review-Kommentare mit einer kurzen Ein-Satz-Zusammenfassung des Fix.
- Begründe kurz, *warum* der Befund ein Problem ist (1–3 Sätze).
- Falls möglich: konkrete Vorschläge in Form von „was ändern“ (keine weiten Refactors).

## Guardrails (Human-in-the-loop)
- Reviews/Kommentare sind Hinweise, keine Wahrheit.
- Der Beitragende muss die Änderung verstehen und selbst verifizieren.
- Keine sensiblen Daten (Tokens/Keys/Secrets) in Kommentaren offenlegen.

## Bewusste Produktentscheidungen (nicht als Finding melden)
- Eingebettetes GitHub-Issues-Token in **macOS**-Produkt-Builds (nicht im iOS-App-Store-Archive): siehe `docs/ci/github-issues-token.md` und `.cursor/rules/codereview-exclusions.mdc`.
- Nicht als Blocking-Security-Finding flaggen, wenn der Diff nur die dokumentierte macOS-Einbettung bzw. das bewusste Weglassen im Store-Archive betrifft.

## Kontext: PR-Template
- Orientiere dich am PR-Template in `.github/PULL_REQUEST_TEMPLATE.md`, aber ergänze keine Inhalte, die
  die Vorlage bereits abdeckt, ohne einen inhaltlichen Grund.

