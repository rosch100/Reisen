# Private iOS-Distribution (ReiseniOSPrivate)

Die **Private-iOS-App** (`de.reisen.Reisen.ios.private`, Anzeigename „Reisen Sync“) enthält den vollständigen Provider-Abruf. Sie wird **nicht** im App Store gelistet.

Die **App-Store-App** (`de.reisen.Reisen.ios`) enthält keinen Provider-Sync-Code im Binary; Buchungen aus Mac/Private/iCloud erscheinen dort über CloudKit.

Beide Apps plus macOS nutzen denselben CloudKit-Container `iCloud.de.reisen.Reisen` (im Developer Portal an **drei** App-IDs binden).

## Build

```bash
bash ./Scripts/ios-archive-adhoc.sh
```

Ausgabe: `.build/ReiseniOSPrivate-ipa/*.ipa`

Voraussetzung: Geräte-UDIDs im Developer Portal registriert (Ad-Hoc-Provisioning).

App Store (ohne Provider):

```bash
bash ./Scripts/ios-archive-appstore.sh
```

## Ad Hoc (empfohlen für Dauerbetrieb)

| | |
|--|--|
| Identifikation | Geräte-**UDID** (Einstellungen → Allgemein → Info, oder Finder) |
| App-Store-Review | **Keins** |
| Limit | 100 Geräte pro Geräteklasse und Jahr |
| Updates | Neues IPA manuell installieren (Finder / Apple Configurator) |

Ablauf:

1. UDID im [Developer Portal](https://developer.apple.com/account/resources/devices/list) registrieren
2. `bash ./Scripts/ios-archive-adhoc.sh`
3. IPA auf registrierte Geräte installieren

## Internal TestFlight (optional, Updates bequemer)

| | |
|--|--|
| Identifikation | **Apple-ID** als Nutzer in App Store Connect (Einladung per E-Mail) |
| App-Store-Review | **Keins** für Internal Tester (nur Processing) |
| Limit | 100 Personen mit App-Store-Connect-Rolle |
| Haltbarkeit | Build **90 Tage**, dann neuer Upload nötig |

**Nicht** External TestFlight oder Public Link verwenden — dann greift Beta App Review (Guideline 5.2.2).

Internal TestFlight-Upload: Release-Build der **Private**-App nach App Store Connect (wie App Store), nur der Gruppe „Internal Testing“ zuweisen — **nie** „External Testing“.

## Was Apple nicht bietet

Keine Whitelist „nur diese Apple-IDs dürfen installieren“ außerhalb des Developer-Teams. Ad Hoc = UDIDs; Internal TestFlight = Team-Nutzer in App Store Connect.

## Siehe auch

- [app-store-connect.md](app-store-connect.md) — Store-App Checkliste
- [apple-signing.md](apple-signing.md) — Signing, Container, Bundle-IDs
