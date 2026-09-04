# Voyenna App Icon — Design

Stand: 2026-09-04

## Zweck

Das bestehende iOS-App-Icon ist weder HIG-full-bleed noch iOS-26-tauglich (weiße Ränder um gebackene Rundung, Soft-Shadow, starke Telegram-Ähnlichkeit, flaches Einzel-PNG statt Icon Composer). Ziel: neue Voyenna-Marke mit klarer Silhouette und Liquid-Glass-fähiger Endlieferung.

## Entscheidungen

| Thema | Entscheidung |
| --- | --- |
| Motive (parallel) | (1) V-Monogramm (2) Voyage-Symbol (3) Flugzeug-Evolution |
| Farbwelten (parallel) | (A) Blau-Cyan (B) Navy→Teal/Indigo (C) Navy+warmer Akzent (D) Fast monochrom |
| Phase 1 | 12 Preview-PNGs 1024×1024 zum Vergleich |
| Phase 2 | Nur der Gewinner als Icon-Composer-Asset (Layer) verdrahten |
| Ablage Previews | `docs/design/voyenna-icon-previews/` (kein Produkt-Asset) |
| Produkt-Assets (nach Auswahl) | `Apps/ReiseniOS/Assets.xcassets` + macOS `Resources/` analog |

## Preview-Matrix (Phase 1)

Dateinamen:

| | A blau-cyan | B voyage-deep | C warm-accent | D mono |
| --- | --- | --- | --- | --- |
| 1 V | `01-v-blue.png` | `02-v-deep.png` | `03-v-warm.png` | `04-v-mono.png` |
| 2 Voyage | `05-voyage-blue.png` | `06-voyage-deep.png` | `07-voyage-warm.png` | `08-voyage-mono.png` |
| 3 Plane | `09-plane-blue.png` | `10-plane-deep.png` | `11-plane-warm.png` | `12-plane-mono.png` |

### Motiv-Briefs

1. **V-Monogramm** — Geometrisches „V“ als Markenzeichen; maximal lesbar in Clear/Tinted; kein zusätzliches Bildmotiv.
2. **Voyage-Symbol** — Stilisiertes Reisezeichen (Kompassnadel, Route oder Horizont-Bogen); kein Papierflugzeug; Silhouette muss ohne Farbe funktionieren.
3. **Flugzeug-Evolution** — Papierflieger-Metapher beibehalten, aber Form/Proportion/Winkel klar von Telegram unterscheidbar; kein kreisförmiges Badge.

### Palette-Briefs

- **A Blau-Cyan:** Diagonale Navy→Cyan wie bisherige Markenfarbe, aber Full-bleed.
- **B Voyage-deep:** Dunkleres Navy→Teal/Indigo, ruhiger, weniger Messenger-Assoziation.
- **C Warm-accent:** Kühler Navy-Grund, ein warmer Akzent (Coral oder Gold) nur am Glyph oder als schmaler Highlight — nicht als Vollflächen-Warmton.
- **D Mono:** Nahezu monochrom (Hell auf Dunkel oder inverse Variante); Farbe sekundär; Preview für Clear/Tinted-Robustheit.

### HIG-Regeln für alle Previews

- Exakt 1024×1024, RGB, **kein Alpha**, Farbe bis zum Pixelrand.
- Keine gebackenen Squircle-/Corner-Masken, keine weißen Ränder.
- Kein Text außer dem „V“ im Monogramm.
- Keine gebackenen Drop-Shadows, Bevels oder Gloss.
- Ein klares Vordergrund-Glyph; bei ~60 pt noch erkennbar.

## Phase 2 (Gewinner: `11c-plane-warm-ai-fullbleed.png`)

- Master installiert via `Scripts/install-voyenna-app-icon.py`.
- iOS: `AppIcon` (dunkel, Primary) + `AppIconLight` (hell, Alternate, wählbar in Einstellungen).
- macOS: `Resources/AppIcon.icns` + `AppIconLight.icns`; Dock/Finder über `CFBundleIconFile` (kein manuelles Application-Icon-Bitmap — sonst eckig).
- Legal/Web: `docs/legal/assets/app-icon.png` (Squircle + Alpha für Favicon/Hero); `apple-touch-icon.png` full-bleed.
- Targets referenzieren beide `.icon`-Pakete; `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS: YES`.

## Nicht im Scope (Phase 1)

- ~~Ersetzen des produktiven Icons~~ (erledigt in Phase 2)
- ~~Icon-Composer-Datei erzeugen~~ (erledigt: `Apps/Shared/AppIcon.icon`)
- ASC-Marketing-Asset-Upload
- ~~Website-`docs/legal/assets/app-icon.png`~~ (erledigt)

## Akzeptanz Phase 1

- 12 PNGs unter `docs/design/voyenna-icon-previews/` mit obigen Namen.
- Stichprobe: Ecken-Pixel ≠ Weißrand-Muster; `hasAlpha: no`.
- Kurze Vergleichsnotiz (welche Varianten Silhouette/Marke am klarsten).

## Akzeptanz Phase 2

- [x] Gewinner `11c` verdrahtet (Asset Catalog + `.icon` + `.icns` + Legal).
- [x] `ictool` Preview iOS Light erzeugt lesbares Paper-Plane-Icon.
- [x] `AppIcon.icon` als `wrapper.icon` in `Reisen.xcodeproj` (Store, Private, Mac).
- Simulator/Device-Smoke: neues Icon auf Homescreen (manuell nach nächstem Build).
