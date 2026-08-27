# App Store Connect — Checkliste (ReiseniOS)

Technische Voraussetzungen im Repo sind in [apple-signing.md](apple-signing.md) und `Scripts/ios-archive-appstore.sh` beschrieben. Diese Checkliste gilt für **manuelle** Schritte in App Store Connect vor der ersten Einreichung.

## App-Informationen

| Feld | Wert / Hinweis |
|------|----------------|
| Name | Reisen |
| Bundle-ID | `de.reisen.Reisen.ios` (siehe `project.yml`) |
| Kategorie | Reisen |
| Privacy Policy URL (DE) | `https://rosch100.github.io/Reisen/privacy.html` (`LegalURLs.privacyPolicyGerman`) |
| Privacy Policy URL (EN) | `https://rosch100.github.io/Reisen/en/privacy.html` (`LegalURLs.privacyPolicyEnglish`) |
| Support URL (DE) | `https://rosch100.github.io/Reisen/support.html` (`LegalURLs.supportGerman`) |
| Support URL (EN) | `https://rosch100.github.io/Reisen/en/support.html` (`LegalURLs.supportEnglish`) |
| Übersicht / beide Sprachen | `https://rosch100.github.io/Reisen/` — zweisprachige **Produktseite** (DE: `/`, EN: `/en/`); Legal: Datenschutz, Support, Impressum |
| Copyright | wie in Info.plist (`NSHumanReadableCopyright`) |

**Vor Einreichung (Pflicht):**

1. `docs/legal/**` auf `master` pushen.
2. GitHub Pages aktivieren (Repository → Settings → Pages → Source: **GitHub Actions**).
3. Workflow `GitHub Pages` ausführen lassen und prüfen, dass beide URLs im Browser **HTML gerendert** anzeigen (kein 404).
4. Bis Pages live ist: vorübergehend Raw-URLs in ASC (`LegalURLs.privacyPolicyRaw` / `LegalURLs.supportRaw`) — **nicht** in der App verlinken (Plain-Text in Safari).

## Altersfreigabe

- Provider-WKWebViews zeigen **uneingeschränkten Webinhalt** (Hotels, Flüge, ggf. nutzergenerierte Inhalte auf Anbieterseiten).
- Im Fragebogen ehrlich angeben; oft **nicht** 4+.
- Keine In-App-Käufe, kein eigenes Nutzerkonto in der App.

## App Privacy (Nutrition Labels)

Abgleich mit `Apps/ReiseniOS/PrivacyInfo.xcprivacy`:

| Datentyp | Verknüpft | Tracking | Zweck |
|----------|-----------|----------|-------|
| Nutzerinhalte (Buchungen, optionales Feedback) | Ja | Nein | App-Funktionalität |
| E-Mail (Provider-Keychain, Opt-in) | Ja | Nein | App-Funktionalität |
| Nutzer-ID (iCloud / CloudKit) | Ja | Nein | App-Funktionalität |
| Kalender/Erinnerungen (EventKit, Opt-in) | Ja | Nein | App-Funktionalität (`OtherUserContent` im Manifest) |

Zusätzlich in ASC angeben, falls gefragt (nicht im Privacy-Manifest `PrivacyInfo.xcprivacy`):

- **Kalender/Erinnerungen** — im Manifest als `OtherUserContent` (Opt-in EventKit); Zweck Stornofristen
- **Provider-Zugangsdaten** in der Keychain — nur Opt-in, lokal auf dem Gerät
- **Uneingeschränkter Webzugriff** in Provider-WebViews (Altersfreigabe-Fragebogen)

## Screenshots

- **iPhone** und **iPad** erforderlich (`TARGETED_DEVICE_FAMILY` 1,2).
- Sinnvolle Szenen: Reiseliste, manuelle Buchung, Stornofristen, Einstellungen (ohne Secrets).

## Review Notes (englisch oder deutsch)

Vorschlag für das Review-Feld:

```
Reisen is a personal trip manager. It is NOT affiliated with Booking.com, Airbnb, Check24, Opodo, GetYourGuide, or Traveloka.

Demo without provider login:
1. Launch the app (iCloud optional).
2. Create a manual booking from the + menu or trip detail.
3. Optional: enable Calendar/Reminders in Settings.

Provider sync (optional): user signs in with their own account in an embedded web view; we cannot provide reviewer credentials for third-party OTAs.

Background mode "remote-notification" is used only for CloudKit silent sync mirroring, not for user-visible push notifications.

No in-app purchases. No Reisen user account. CloudKit uses the reviewer's iCloud account if signed in.
```

## CloudKit (Developer Portal)

- Container `iCloud.de.reisen.Reisen` an **beide** App-IDs binden (macOS + iOS).
- Distribution-Builds: **Production**-Umgebung (Release-Entitlements `aps-environment` = `production`).

## Build hochladen

```bash
bash ./Scripts/ios-archive-appstore.sh
```

Erzeugt Archive + exportiertes IPA unter `.build/ReiseniOS-ipa/`. Upload via Transporter oder `xcodebuild -exportArchive` mit Upload-Option.

## Bekanntes Review-Risiko (Guideline 5.2)

Die App synchronisiert Buchungen über Web-Sessions inoffizieller Provider-APIs. Das ist bewusst so dokumentiert; Ablehnung bleibt möglich. Mitigation: klare Review Notes, manuelle Demo ohne OTA-Login, kein Provider-Branding als App-Icon.
