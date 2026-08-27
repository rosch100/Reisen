# Apple Signing (macOS + iOS)

Team-ID und Bundle-IDs sind **keine Secrets**, werden aber nicht in dieser Doku dupliziert — SSOT ist `project.yml` (`DEVELOPMENT_TEAM`, Bundle-IDs pro Target) und `Scripts/setup-apple-developer.sh`.

| Plattform | Bundle-ID | Container |
|-----------|-----------|-----------|
| macOS | siehe `project.yml` → ReisenMac | siehe `PersistenceBootstrap.cloudKitContainerID` |
| iOS App Store | `de.reisen.Reisen.ios` (`ReiseniOS`) | gemeinsamer CloudKit-Container |
| iOS Private | `de.reisen.Reisen.ios.private` (`ReiseniOSPrivate`) | gemeinsamer CloudKit-Container |

Team: **DEVELOPMENT_TEAM** aus `project.yml` oder Umgebungsvariable `APPLE_TEAM_ID` (Automatic Signing).

Lokal eingerichtet (nach `setup-apple-developer.sh`):

- App-IDs für macOS und iOS gemäß `project.yml`
- iCloud-Container (CloudKit) an die macOS-App gebunden
- Mac-Development-Profil in `.signing/Reisen.provisionprofile` (gitignored)
- Keychain: Apple Development, Apple Distribution, Developer ID Application für dieses Team
- GitHub-Secret `APPLE_TEAM_ID`

Noch offen für Geräte-Builds und CI-Notarize: iPhone im Developer Portal (Gerät einschalten und Script erneut), Developer-ID-`.p12` plus App-Store-Connect-API-Key als GitHub-Secrets.

## Lokales Setup

Einmalig (Keychain braucht ein **Apple Development**-Zertifikat dieses Teams):

```bash
bash ./Scripts/setup-apple-developer.sh
```

Das Script:

1. prüft die Development-Identity zur Team-ID aus `project.yml`
2. erzeugt `Reisen.xcodeproj` (XcodeGen, Targets `ReiseniOS`, `ReiseniOSPrivate`, `ReisenMac`)
3. registriert App-IDs/Profiles per Automatic Signing (`xcodebuild -allowProvisioningUpdates`)
4. legt `.signing/Reisen.provisionprofile` ab (gitignored) für `Scripts/build-app.sh`

Wenn Xcode nicht mit der Apple-ID angemeldet ist, schlägt Schritt 3 fehl. Dann:

1. `open Reisen.xcodeproj`
2. Xcode → Settings → Accounts → Apple-ID anmelden
3. Targets **ReiseniOS**, **ReiseniOSPrivate** und **ReisenMac** → Signing & Capabilities → passendes Team wählen
4. Capabilities: **iCloud** (CloudKit, Container laut `project.yml`) und **Push Notifications** (iOS)
5. Script erneut ausführen

`Scripts/build-app.sh` / `Scripts/run-app.sh` signieren lokal mit **Apple Development**, sobald das Profil in `.signing/` liegt. Fehlt es, bleibt der Pfad explizit ad-hoc (CloudKit inaktiv, Hinweis auf das Setup-Script). In CI (`CI=true` / GitHub Actions) ist ad-hoc fest verdrahtet.

iOS-Simulator-Tests in CI setzen `CODE_SIGNING_ALLOWED=NO` — die Runner haben keine Team-Zertifikate.

## macOS CloudKit ohne Push (`aps-environment`)

`Resources/Reisen.entitlements` enthält **kein** `aps-environment` (keine Push Notifications Capability am Mac-Target).

| Plattform | Silent CloudKit Push | Sync-Strategie |
|-----------|----------------------|----------------|
| iOS (Store + Private) | Ja (`aps-environment` in Release-Entitlements) | Hintergrund-Sync via Remote Notifications |
| macOS (`ReisenMac`) | Nein | Foreground-Sync, manueller Abruf, CloudKit-Remote-Change-Observer beim aktiven Fenster |

Das ist bewusst: Mac nutzt denselben CloudKit-Container, aber ohne APNs-Registrierung. Neue Daten von iOS/iPadOS kommen auf dem Mac beim nächsten App-Start oder während die App im Vordergrund ist.

## Release: Developer ID + Notarization (secrets-gated)

Im `release.yml` startet Signing/Notarization **nur**, wenn alle folgenden GitHub-Secrets gesetzt sind:

- `APPLE_DEVELOPER_ID_P12_BASE64`
- `APPLE_DEVELOPER_ID_P12_PASSWORD`
- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`
- `APP_STORE_CONNECT_API_KEY_KEY_ID`
- `APP_STORE_CONNECT_API_KEY_ISSUER`

Fehlen Werte, bleibt der Unsigned-Pfad (kein stiller „signed“-Fallback). `APPLE_TEAM_ID` kann `setup-apple-developer.sh` setzen; die übrigen Secrets kommen aus Zertifikat und App-Store-Connect-Key.

### Developer ID Application Zertifikat

1. [Certificates](https://developer.apple.com/account/resources/certificates/list): **Developer ID Application** erzeugen (CSR aus der Schlüsselbundverwaltung)
2. Zertifikat als `.p12` exportieren
3. Base64 des `.p12` → `APPLE_DEVELOPER_ID_P12_BASE64`
4. Export-Passwort → `APPLE_DEVELOPER_ID_P12_PASSWORD`

### App Store Connect API Key (.p8)

1. [Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api): Key mit Zugang zu Certificates/Identifiers/Profiles (und Notary) anlegen
2. `.p8` Base64 → `APP_STORE_CONNECT_API_KEY_BASE64`
3. Key-ID → `APP_STORE_CONNECT_API_KEY_KEY_ID`
4. Issuer-UUID → `APP_STORE_CONNECT_API_KEY_ISSUER`

Optional lokal: `~/keys/AuthKey_<KEY_ID>.p8` (Fallback: `~/private_keys/AuthKey_<KEY_ID>.p8`). Dann kann `setup-apple-developer.sh` Provisioning nicht-interaktiv über `xcodebuild -authenticationKeyPath` fahren (`APP_STORE_CONNECT_API_KEY_KEY_ID`, `APP_STORE_CONNECT_API_KEY_ISSUER`, optional `APP_STORE_CONNECT_API_KEY_PATH`).

## Befehlspfade (SSOT)

- Team/Identity-Helfer: `Scripts/apple-developer.sh` (sourced)
- Erstes Team-Setup: `bash ./Scripts/setup-apple-developer.sh`
- Signing/Notarize: `Scripts/sign-and-notarize.sh`
  - `.app`: `bash ./Scripts/sign-and-notarize.sh --app-path /abs/path/to/Reisen.app`
  - `.dmg`: `bash ./Scripts/sign-and-notarize.sh --dmg-path /abs/path/to/Reisen.dmg` (sign → notarytool → staple)
- Release Workflow: erst `.app` signieren/notarizen/staplen, dann DMG erzeugen, danach dieselbe Helper-API für die DMG

## iOS App Store (ReiseniOS)

Distribution für den **App Store** (nicht Developer ID):

```bash
bash ./Scripts/ios-archive-appstore.sh
```

Das Script:

1. setzt `REISEN_EMBED_GITHUB_ISSUE_TOKEN=true` und `REISEN_REQUIRE_GITHUB_ISSUE_TOKEN=true` (Issues-Token Pflicht, damit Nutzer ohne GitHub-Konto melden können)
2. ruft `Scripts/generate-ios-project.sh` auf
3. erzeugt ein **Release**-Archive (`xcodebuild archive`, `generic/platform=iOS`)
4. exportiert ein IPA (`Scripts/ios-export-appstore.plist`, `method: app-store`)

Ausgabe: `.build/ReiseniOS-ipa/*.ipa`. Upload per Transporter oder App Store Connect. Vor dem Upload: manueller Workflow **App Store Check** ([`appcompliance.md`](appcompliance.md)).

Voraussetzungen:

- Lokal: Xcode mit angemeldeter Apple-ID und **Apple Distribution** für `de.reisen.Reisen.ios`
- In GitHub Actions (**App Store Check**): App-Store-Connect-API-Key (`APP_STORE_CONNECT_API_KEY_*`) statt Xcode-Account; `ios-archive-appstore.sh` materialisiert das `.p8` über `reisen_xcodebuild_asc_auth_args`
- Push Notifications + iCloud (CloudKit) in den Capabilities; Release-Entitlements `ReiseniOS-Release.entitlements` mit `aps-environment` = `production`
- CloudKit-Container im Developer Portal an die iOS App-ID gebunden (Production)

Checkliste für Metadaten, Screenshots und Review Notes: [`app-store-connect.md`](app-store-connect.md).

Private-iOS (Ad Hoc): [`ios-private-distribution.md`](ios-private-distribution.md), `Scripts/ios-archive-adhoc.sh`.

## Validierung / Troubleshooting

- Keychain ohne „Apple Development“ zum Team: `setup-apple-developer.sh` bricht ab (kein stiller Ad-hoc-Pfad lokal)
- Keychain Identity für Notary nicht gefunden: importiertes Zertifikat muss **Developer ID Application** sein; Keychain entsperrt/importiert
- App Store Check `exportArchive` / **Cloud signing permission error**: der App-Store-Connect-API-Key braucht Zugriff auf **Cloud Managed Distribution Certificates** (Account Holder/Admin in [Users and Access](https://appstoreconnect.apple.com/access/users)). Ohne das findet Xcode kein iOS-App-Store-Profil für `de.reisen.Reisen.ios`. Developer-ID-`.p12` (macOS) ersetzt das nicht.
- Notarization: `notarytool submit --wait` liefert die Apple-Antwort in den Workflow-Logs
- CloudKit: Container laut `PersistenceBootstrap.cloudKitContainerID` muss im Portal an **drei** App-IDs gebunden sein (macOS, Store-iOS, Private-iOS)
