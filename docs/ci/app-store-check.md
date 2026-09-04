# App Store Check (manuell)

Zur **Release-Vorbereitung** erzeugt der Workflow **App Store Check** (`app-store-check.yml`) das Store-IPA (`ReiseniOS`, Bundle-ID `app.voyenna.reisen.ios`) und prüft Signing, Store-Isolation und Apples ITMS-Validierung (`xcrun altool --validate-app`). Private-iOS (`ReiseniOSPrivate` / `app.voyenna.reisen.ios.private`) wird nicht archiviert. Der Workflow ersetzt nicht die PR-CI.

| Wann | Was |
|------|-----|
| Jeder PR gegen `master` / Push `master` | Workflow **CI**: Swift-Tests, iOS-Simulator, Release-Binary-Isolation (Store **und** Private getrennt) |
| Manuell vor Einreichung | Workflow **App Store Check**: Store-Archive (`Scripts/ios-archive-appstore.sh`) + Isolation + `altool --validate-app` |

Der Workflow prüft **technische** Apple-Annahme (ITMS): Signing, Entitlements, Icons, Privacy-Manifest-Pflicht u. a. `product-errors`. Das ist **kein** Check der App-Store-Review-Guidelines (Mindestfunktion, 4.3, Datenschutztexte, Design). Die gehen weiter manuell vor der Einreichung.

`altool --validate-app` schickt das IPA an Apple zur Prüfung und lädt es **nicht** zur Review hoch. GitHub bekommt kein IPA-Artifact (öffentliches Repo, eingebettetes Issues-PAT, siehe [`github-issues-token.md`](github-issues-token.md)). Auf dem selbstgehosteten Runner löscht der Workflow IPA und Archive nach der Validierung (`if: always()`), auch bei fehlgeschlagenem Check.

## Wann der Workflow läuft

Nur **on demand** (`workflow_dispatch`): Actions → **App Store Check** → Run workflow.

Kein Lauf auf PRs, Push oder Tags: Archive braucht Apple Distribution.

## GitHub-Secrets

Repository → Settings → Secrets and variables → Actions:

| Secret | Inhalt |
|--------|--------|
| `REISEN_GITHUB_ISSUES_TOKEN_BASE64` | Issues-only-PAT für das Produkt-Binary |
| `APP_STORE_CONNECT_API_KEY_BASE64` | App-Store-Connect-API-Key (`.p8`, Base64) |
| `APP_STORE_CONNECT_API_KEY_KEY_ID` | Key-ID |
| `APP_STORE_CONNECT_API_KEY_ISSUER` | Issuer-ID |
| `APPLE_TEAM_ID` | Apple Team-ID |

Werte nur aus GitHub-Secrets, nie aus dem Repo. Workflows loggen sie nicht.

## Voraussetzungen für das Archive

Runner und Signing für `bash ./Scripts/ios-archive-appstore.sh`:

- `xcode-27` mit XcodeGen (`brew install xcodegen`)
- In GitHub Actions: App-Store-Connect-API-Key plus `APPLE_TEAM_ID`. Der Key braucht Zugriff auf **Cloud Managed Distribution Certificates** (Account Holder/Admin). Details: [`apple-signing.md`](apple-signing.md).
- Lokal: Xcode mit angemeldeter Apple-ID und **Apple Distribution** für `app.voyenna.reisen.ios`, oder derselbe API-Key wie in CI.
- Automatic Signing (`-allowProvisioningUpdates`)

Das Archive-Script archiviert ausschließlich Scheme `ReiseniOS`. Isolation muss greifen (sonst Abbruch):

- Bundle-ID `app.voyenna.reisen.ios` (nicht `.private`)
- App-Name `ReiseniOS.app` (nicht `ReiseniOSPrivate.app`)
- keine Provider-Adapter-Strings/Symbole im IPA (`ios-verify-binary-isolation.sh --mode store --ipa`)

Die gleiche Isolation läuft in der PR-CI über Simulator-Release-Builds (`ios-build-release-check.sh`).

Details: [`apple-signing.md`](apple-signing.md), [`app-store-connect.md`](app-store-connect.md).

## Ablauf

1. Store-IPA erzeugen (`Scripts/ios-archive-appstore.sh`).
2. Isolation auf dem IPA prüfen.
3. Apple ITMS-Validierung (`Scripts/ios-validate-appstore.sh` → `xcrun altool --validate-app`).
4. IPA und Archive auf dem Runner löschen (kein GitHub-Artifact).

Lokal: zuerst das Store-IPA erzeugen, dann denselben Pfad validieren (ASC-API-Key wie in CI). `.build/` von SwiftPM enthält kein IPA. In App Store Connect muss die iOS-App `app.voyenna.reisen.ios` existieren (Listename **Voyenna**), sonst bricht `altool` mit „Unable to find Apple ID for Bundle ID“ ab — siehe [`app-store-connect.md`](app-store-connect.md). ITMS 90534: Xcode 27 auf die **neueste** Beta/RC bringen, IPA neu bauen.

```bash
IPA="$(bash ./Scripts/ios-archive-appstore.sh)"
bash ./Scripts/ios-validate-appstore.sh "$IPA"
```

## Was der Workflow nicht prüft

- App-Store-Review-Guidelines (Reviewer-Themen, nicht ITMS)
- Private-iOS (`Scripts/ios-archive-adhoc.sh`, Bundle-ID `app.voyenna.reisen.ios.private`)
- macOS `.app` / DMG
