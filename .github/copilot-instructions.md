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

## Kontext: PR-Template
- Orientiere dich am PR-Template in `.github/PULL_REQUEST_TEMPLATE.md`, aber ergänze keine Inhalte, die
  die Vorlage bereits abdeckt, ohne einen inhaltlichen Grund.

