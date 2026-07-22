# Cursor Agents für Reisen

Dieses Repo nutzt Cursor-Agents primär für saubere CI-/Review-Workflows. Die „Agents“ sind nicht Magic, sondern Leitplanken, was in Änderungen erwartet wird.

## Rollen

### CI-Agent (Build/Test)
- Ziel: `./Scripts/ci-test.sh` lokal und im CI zuverlässig ausführen.
- Regel: Wenn CI fehlschlägt, wird erst Root-Cause analysiert (log/stack), dann gefixt.
- Zielpfade: `.github/workflows/ci.yml`, `Scripts/ci-test.sh`, `Scripts/build-app.sh`.

### Review-Agent (Qualität / Grenzen)
- Ziel: keine Scope-Ausweitung ohne Absprache.
- Fokus: Domain-Grenzen (`ReisenDomain`, `ReisenData`, `ReisenProviders`) und „keine stillen Fallbacks“.

### Security-Agent (Secrets / Supply Chain)
- Ziel: Secrets nie in Logs oder Artefakten ausgeben.
- Fokus: `release.yml`, `Scripts/sign-and-notarize.sh`, `docs/ci/apple-signing.md`.
- Regel: Nur Secrets aus GitHub (`secrets.*`) verwenden; keine Hardcodings.

## Lokale Kommandos (SSOT zu CI)

- Test (CI-parität): `bash ./Scripts/ci-test.sh`
- App-Bundle bauen: `bash ./Scripts/build-app.sh --configuration debug|release`

