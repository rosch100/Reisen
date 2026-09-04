# Voyenna App Icon Previews — Implementation Plan

> **For agentic workers:** Phase 1 = generate 12 HIG preview PNGs per `docs/superpowers/specs/2026-09-04-voyenna-app-icon-design.md`. Phase 2 only after user picks a winner.

**Goal:** Ship 12 full-bleed 1024×1024 RGB previews under `docs/design/voyenna-icon-previews/`, then stop for selection.

**Architecture:** One Python generator (`Scripts/generate-voyenna-icon-previews.py`) draws gradients + vector glyphs with Pillow (no baked corners/shadows). Output names match the spec matrix.

### Task 1: Generator + 12 PNGs

**Files:**
- Create: `Scripts/generate-voyenna-icon-previews.py`
- Create: `docs/design/voyenna-icon-previews/{01..12}-*.png`
- Create: `docs/design/voyenna-icon-previews/README.md` (Vergleichsnotiz)

**Steps:**
1. Implement palettes A–D and motifs V / Voyage / Plane.
2. Run script; verify corner pixels are not white-margin pattern; `hasAlpha: no`.
3. Write short README comparing silhouette/brand clarity.

**Done when:** Spec Phase-1 Akzeptanz erfüllt; no productive AppIcon replaced.
