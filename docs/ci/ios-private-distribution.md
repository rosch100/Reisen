# Private iOS-Distribution (ReiseniOSPrivate)

Die **Private-iOS-App** (`app.voyenna.reisen.ios.private`, Anzeigename „Voyenna Sync“) enthält den vollständigen Provider-Abruf. Sie wird **nicht** im App Store gelistet.

Die **App-Store-App** (`app.voyenna.reisen.ios`) enthält keinen Provider-Sync-Code im Binary; Buchungen aus Mac/Private/iCloud erscheinen dort über CloudKit.

Beide Apps plus macOS nutzen denselben CloudKit-Container `iCloud.app.voyenna.reisen` (im Developer Portal an **drei** App-IDs binden).

## Builds

Ad Hoc (Geräte-UDID):

```bash
bash ./Scripts/ios-archive-adhoc.sh
```

Ausgabe: `.build/ReiseniOSPrivate-ipa/*.ipa`

Voraussetzung: Geräte-UDIDs im Developer Portal registriert (Ad-Hoc-Provisioning).

Internal TestFlight (App-Store-Connect-Export, kein Store-Listing):

```bash
bash ./Scripts/ios-archive-private-testflight.sh
```

Ausgabe: `.build/ReiseniOSPrivate-testflight-ipa/*.ipa`

App Store (ohne Provider, separates Target):

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

### Einmalig in App Store Connect

1. Neue iOS-App anlegen (UI, Account Holder/Admin): Bundle-ID `app.voyenna.reisen.ios.private`, Name z. B. **Voyenna Sync**, SKU z. B. `voyenna-ios-private`.
   - Der ASC-API-Key darf Apps typischerweise **nicht** anlegen (`CREATE` auf `apps` ist oft gesperrt) — Anlage nur in [App Store Connect → Meine Apps → +](https://appstoreconnect.apple.com/apps).
2. **Kein** Store-Listing / keine Review-Einreichung nötig (nur TestFlight Internal).
3. Unter [Users and Access](https://appstoreconnect.apple.com/access/users) Tester mit Rolle einladen (Admin, App Manager, Developer, Marketing, …).
4. CloudKit-Container `iCloud.app.voyenna.reisen` an diese App-ID gebunden (siehe [`apple-signing.md`](apple-signing.md)).

### Release-Ablauf

1. Build-Nummer eindeutig halten (`CURRENT_PROJECT_VERSION` in `project.yml` / `CFBundleVersion`) — jeder ASC-Upload braucht eine neue Build-Nummer für dieselbe Marketing-Version.
2. IPA erzeugen:

```bash
IPA="$(bash ./Scripts/ios-archive-private-testflight.sh)"
echo "$IPA"
```

3. Hochladen (ASC-API-Key wie Store-Pfad: `APP_STORE_CONNECT_API_KEY_*`):

```bash
bash ./Scripts/ios-upload-testflight.sh "$IPA"
```

   Alternativ: Transporter / Xcode Organizer mit demselben IPA.

4. In App Store Connect → App **Voyenna Sync** → **TestFlight** → warten bis Status **Ready to Test** (Processing).
5. **Internal Testing**-Gruppe anlegen oder öffnen → Build zuweisen → Tester hinzufügen.
6. **Nie** „External Testing“ oder Public Link für diese App.

### Checkliste vor dem Upload

- [ ] ASC-App für `app.voyenna.reisen.ios.private` existiert
- [ ] Tester haben ASC-Rollen und TestFlight-App
- [ ] Neue Build-Nummer, falls dieselbe Version schon hochgeladen wurde
- [ ] `ios-archive-private-testflight.sh` grün (Private-Isolation geprüft)
- [ ] Upload nur Internal Testing zugewiesen

## Was Apple nicht bietet

Keine Whitelist „nur diese Apple-IDs dürfen installieren“ außerhalb des Developer-Teams. Ad Hoc = UDIDs; Internal TestFlight = Team-Nutzer in App Store Connect.

## Siehe auch

- [app-store-connect.md](app-store-connect.md) — Store-App Checkliste
- [apple-signing.md](apple-signing.md) — Signing, Container, Bundle-IDs
