---
name: ui-surface-review
description: >-
  Reviews macOS UI surface dumps (screenshot, AX JSON, manifest) against HIG,
  logic, and design. Use after bash ./Scripts/macos-ui-review.sh or when the
  user asks for UI-surface review, HIG audit, or screenshot dump evaluation.
---

# UI-Surface-Review

Advisory only. Kein Merge-Gate, kein Score.

## Pflicht zuerst

1. Artifacts lesen: `manifest.json` (`schemaVersion`), PNG, `*.ax.json`.
2. Artifact-Pfad:
   - Script `Scripts/macos-ui-review.sh`: `$REISEN_UI_REVIEW_DIR` (Default `DerivedData/ui-review/<timestamp>/`), plus Export aus xcresult-Attachments.
   - Standalone `ReviewArtifactWriter` (ohne Script): Prozess-Temp `…/reisen-ui-review-<uuid>/` und `XCTAttachment` (Sandbox schreibt nicht zuverlässig nach `/tmp`).
3. Rubrik: [`docs/qa/ui-review-rubric.md`](../../../docs/qa/ui-review-rubric.md).
4. HIG-Ist: [`docs/superpowers/specs/2026-07-20-hig-core-ux-review.md`](../../../docs/superpowers/specs/2026-07-20-hig-core-ux-review.md).

**Abbruch**, wenn Manifest, PNG oder AX-JSON fehlen — oder kein Modell verfügbar ist. Keine erfundenen Screens.

## Ablauf

1. Manifest `schemaVersion` und `platform` prüfen.
2. Jeden Screen (PNG + AX) gegen HIG / Unlogik / Design halten.
3. Nur belegen, was Screenshot oder AX-Knoten zeigt (identifier, label, frame, enabled, hittable).
4. Findings auf Deutsch mit Severity `blocker` / `major` / `minor` / `nit`.
5. Jedes Finding: `severity`, `category` (`hig` / `unlogik` / `design`), `title`,
   `evidence.screenshot` (PNG-Dateiname), `evidence.ax` (Identifier oder AX-Knoten),
   `why`, `fix`.

## Beziehung zu Observability/Tests

Neue UI-Flächen brauchen Identifier + XCUI-Smoke **im Feature-Diff** (Rule `reisen-logging-and-tests`, Skill `reisen-observability-tests`). Dieser Skill bewertet nur advisory Review-Dumps.

## Nicht tun

- CI rot machen oder Merge blockieren.
- Pixel-Regression oder 44pt-Hit-Region als Gate behaupten.
- iOS-Simulator-Verhalten aus macOS-Dumps ableiten.
- VoiceOver-Durchlauf vortäuschen.
