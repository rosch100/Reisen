# App Store Check (manuell)

Zur **Release-Vorbereitung** prüft der Workflow **App Store Check** (`app-store-check.yml`) das Store-IPA gegen Apple-/Store-Anforderungen. Er ersetzt nicht die PR-CI.

| Wann | Was |
|------|-----|
| Jeder PR / Push `master` | Workflow **CI**: Swift-Tests, iOS-Simulator, Release-Binary-Isolation |
| Manuell vor Einreichung | Workflow **App Store Check**: Archive (`Scripts/ios-archive-appstore.sh`) + [AppCompliance](https://appcompliance.io/)-Scan |

Der Scan folgt dem [GitHub-Action-Setup](https://appcompliance.io/blog/github-action-compliance-scanning-setup/). Das IPA enthält kein GitHub-PAT. Findings landen optional als SARIF in GitHub Code Scanning.

AppCompliance ist derzeit Early Access. Die Action `appcompliance/scan@v1` wird auf den Commit-SHA gepinnt, sobald das Action-Repo öffentlich ist (Dependabot).

## Wann der Workflow läuft

Nur **on demand** (`workflow_dispatch`): Actions → **App Store Check** → Run workflow. Fehlen die Secrets, schlägt der Lauf in `preflight` fehl (kein stiller Skip).

Kein Lauf auf PRs, Push oder Tags: Archive braucht Apple Distribution, und jedes IPA würde an AppCompliance hochgeladen.

## GitHub-Secrets

Repository → Settings → Secrets and variables → Actions:

| Secret | Inhalt |
|--------|--------|
| `APPCOMPLIANCE_TOKEN` | API-Token mit CI/CD-Scope (AppCompliance → Settings → API Tokens) |
| `APPCOMPLIANCE_API_URL` | API-Basis-URL, z. B. `https://app.appcompliance.io` |

Beide Werte kommen nur aus GitHub-Secrets, nie aus dem Repo. Workflows loggen sie nicht.

Ohne Token/URL: der manuelle Lauf bricht in `preflight` ab.

## Gating

Aktuell **Notify-only** (`continue-on-error: true`): Findings erscheinen im Log und als SARIF, der Workflow bleibt grün. Das ist der Onboarding-Modus aus dem AppCompliance-Guide — Reisen hat noch keine bereinigte Baseline.

Hard Gate (blocking findings stoppen den Lauf): `continue-on-error` am Scan-Step entfernen. Regression-Modus (`mode: regression`) erst nach einem ersten erfolgreichen Scan, der die Baseline setzt.

## Voraussetzungen für das Archive

Derselbe Runner und dasselbe Signing wie lokal für `bash ./Scripts/ios-archive-appstore.sh`:

- `xcode-27` mit XcodeGen (`brew install xcodegen`)
- Apple Distribution für `de.reisen.Reisen.ios` und Automatic Signing (`-allowProvisioningUpdates`)

Das Archive-Script prüft zusätzlich die Binary-Isolation am Store-`.app` im Archive. Die gleiche Isolation läuft in der PR-CI über Simulator-Release-Builds (`ios-build-release-check.sh`).

Details: [`apple-signing.md`](apple-signing.md), [`app-store-connect.md`](app-store-connect.md).

## Ablauf

1. Store-IPA erzeugen (`Scripts/ios-archive-appstore.sh`).
2. IPA als Artifact `reisen-ios-ipa` (Retention 1 Tag) an den Scan-Job.
3. `appcompliance/scan@v1` lädt das IPA hoch, schreibt `appcompliance-report.json` und `appcompliance.sarif`.
4. SARIF-Upload, falls die Datei existiert (`if: always()`).

Exit-Codes der Action (laut AppCompliance): 0 pass, 1 fail (blocking findings), 2 Fehler (Auth/Netz/Timeout). Bei Notify-only scheitert der Job trotzdem nicht.

## Was nicht gescannt wird

- Private-iOS (`Scripts/ios-archive-adhoc.sh`) — Provider-Binary, nicht die Store-Einreichung
- macOS `.app` / DMG — AppCompliance erwartet IPA, APK oder AAB
