# UI-Surface-Review-Rubrik (advisory)

**Plattform v1:** macOS. Kein CI-Gate, kein Score, kein Merge-Blocker.

## Quellen

- Artifacts der Tour: `manifest.json` (`schemaVersion`), PNG, AX-JSON (XCUI-Walk).
- HIG-Kontext: [2026-07-20-hig-core-ux-review.md](../superpowers/specs/2026-07-20-hig-core-ux-review.md).
- Apple Human Interface Guidelines, macOS.

## Abbruch

Ohne Manifest, ohne mindestens ein PNG **oder** ohne AX-JSON: **abbrechen**. Keine erfundenen Screens, keine Spekulation über unsichtbare Flächen.

Fehlt das Modell: ebenfalls abbrechen, keinen Platzhalter-Report schreiben.

## Kategorien

| Kategorie | Fragt |
|-----------|--------|
| **HIG** | Discoverability, Menüs, Empty States, destruktive Confirms, Hilfen, Fokus, Standard-Chrome |
| **Unlogik** | Zustand und Aktion passen nicht zusammen; toter Control; irreführender Text; Navigation ohne Ziel |
| **Design** | Hierarchie, Dichte, Alignment, Kontrast-Auffälligkeiten (kein Labor-Messwert in v1) |

## Severity

| Stufe | Bedeutung |
|-------|-----------|
| `blocker` | Kernjourney unbenutzbar oder irreversibel destruktiv ohne Confirm |
| `major` | HIG-/Logikbruch, der Nutzer:innen regelmäßig trifft |
| `minor` | Behebbar, Journey bleibt möglich |
| `nit` | Feinschliff |

## Finding-Pflichtfelder

Jedes Finding auf Deutsch:

- `severity`
- `category` (`hig` / `unlogik` / `design`)
- `title`
- `evidence.screenshot` (PNG-Dateiname)
- `evidence.ax` (Identifier oder AX-Knoten)
- `why` (was verletzt wird)
- `fix` (konkreter nächster Schritt)

Kein numerischer Score. Keine „insgesamt gut“-Zusammenfassung als Ersatz für Findings.
