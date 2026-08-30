---
name: ui-surface-review
description: >-
  Bewertet macOS-UI-Review-Dumps (Screenshot + AX-JSON + Manifest) nach HIG,
  Unlogik und Design. Nutzen nach bash ./Scripts/macos-ui-review.sh oder wenn
  der User UI-Surface-Review, HIG-Audit oder Screenshot-Dumps nennt.
---

# UI-Surface-Review

Advisory only. Kein Merge-Gate, kein Score.

## Pflicht zuerst

1. Artifacts lesen: `manifest.json` (`schemaVersion`), PNG, `*.ax.json`.
2. Default-Pfad: `$REISEN_UI_REVIEW_DIR` oder `DerivedData/ui-review/<timestamp>/`.
3. Rubrik: [`docs/qa/ui-review-rubric.md`](../../../docs/qa/ui-review-rubric.md).
4. HIG-Ist: [`docs/superpowers/specs/2026-07-20-hig-core-ux-review.md`](../../../docs/superpowers/specs/2026-07-20-hig-core-ux-review.md).

**Abbruch**, wenn Manifest, PNG oder AX-JSON fehlen — oder kein Modell verfügbar ist. Keine erfundenen Screens.

## Ablauf

1. Manifest `schemaVersion` und `platform` prüfen.
2. Jeden Screen (PNG + AX) gegen HIG / Unlogik / Design halten.
3. Nur belegen, was Screenshot oder AX-Knoten zeigt (identifier, label, frame, enabled, hittable).
4. Findings auf Deutsch mit Severity `blocker` / `major` / `minor` / `nit`.
5. Jedes Finding: Evidence (PNG-Name + AX-Identifier oder Knoten), Why, Fix.

## Nicht tun

- CI rot machen oder Merge blockieren.
- Pixel-Regression oder 44pt-Hit-Region als Gate behaupten.
- iOS-Simulator-Verhalten aus macOS-Dumps ableiten.
- VoiceOver-Durchlauf vortäuschen.
