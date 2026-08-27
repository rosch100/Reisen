# App Store Connect — Checkliste (ReiseniOS, Store)

Technische Voraussetzungen im Repo sind in [apple-signing.md](apple-signing.md) und `Scripts/ios-archive-appstore.sh` beschrieben. Diese Checkliste gilt für die **App-Store-Variante** (`de.reisen.Reisen.ios`) — **ohne** Provider-Abruf im Binary.

Vollständiger Provider-Sync: separate Private-iOS-App, siehe [ios-private-distribution.md](ios-private-distribution.md).

## App-Informationen

| Feld | Wert / Hinweis |
|------|----------------|
| Name | Reisen |
| Bundle-ID | `de.reisen.Reisen.ios` (siehe `project.yml` → `ReiseniOS`) |
| Kategorie | Reisen |
| Privacy Policy URL (DE) | `https://rosch100.github.io/Reisen/privacy.html` (`LegalURLs.privacyPolicyGerman`) |
| Privacy Policy URL (EN) | `https://rosch100.github.io/Reisen/en/privacy.html` (`LegalURLs.privacyPolicyEnglish`) |
| Support URL (DE) | `https://rosch100.github.io/Reisen/support.html` (`LegalURLs.supportGerman`) |
| Support URL (EN) | `https://rosch100.github.io/Reisen/en/support.html` (`LegalURLs.supportEnglish`) |
| Übersicht / beide Sprachen | `https://rosch100.github.io/Reisen/` (`index.html`) |
| Copyright | wie in Info.plist (`NSHumanReadableCopyright`) |

**Vor Einreichung (Pflicht):**

1. `docs/legal/**` auf `master` pushen.
2. GitHub Pages aktivieren (Repository → Settings → Pages → Source: **GitHub Actions**).
3. Workflow `GitHub Pages` ausführen lassen und prüfen, dass beide URLs im Browser **HTML gerendert** anzeigen (kein 404).
4. Bis Pages live ist: vorübergehend Raw-URLs in ASC (`LegalURLs.privacyPolicyRaw` / `LegalURLs.supportRaw`) — **nicht** in der App verlinken (Plain-Text in Safari).

## Altersfreigabe

- **Keine** eingebetteten Provider-WebViews in der Store-App.
- Keine In-App-Käufe, kein eigenes Nutzerkonto in der App.
- Buchungen von Drittanbietern können über **iCloud** von Mac/Private-App synchronisiert werden und werden nur **angezeigt** (kein Abruf bei OTAs).

## App Privacy (Nutrition Labels)

Abgleich mit `Apps/ReiseniOS/PrivacyInfo.xcprivacy` (Store-Variante **ohne** E-Mail-Datentyp):

| Datentyp | Verknüpft | Tracking | Zweck |
|----------|-----------|----------|-------|
| Nutzerinhalte (Buchungen, optionales Feedback) | Ja | Nein | App-Funktionalität |
| Nutzer-ID (iCloud / CloudKit) | Ja | Nein | App-Funktionalität |
| Kalender/Erinnerungen (EventKit, Opt-in) | Ja | Nein | App-Funktionalität (`OtherUserContent` im Manifest) |

Zusätzlich in ASC angeben, falls gefragt (nicht im Privacy-Manifest):

- **Kalender/Erinnerungen** — im Manifest als `OtherUserContent` (Opt-in EventKit); Zweck Stornofristen

**Nicht** angeben (Store-App): Provider-Keychain/E-Mail, uneingeschränkter Webzugriff in OTA-WebViews.

## Screenshots

- **iPhone** und **iPad** erforderlich (`TARGETED_DEVICE_FAMILY` 1,2).
- Sinnvolle Szenen: Reiseliste, **manuelle** Buchung, Stornofristen, Einstellungen (ohne Provider-Sync-Tab).

## Review Notes (englisch oder deutsch)

Nur Funktionen beschreiben, die **in dieser App-Store-Version** vorhanden sind. Keine Erwähnung anderer Builds, Provider-Login oder Buchungsabruf von Drittanbietern — das gibt es in diesem Binary nicht.

Vorschlag für das Review-Feld:

```
Reisen is a personal trip manager for trips and bookings.

Users create bookings manually or receive trip and booking data synced via iCloud (same Apple ID, shared CloudKit container).

Demo:
1. Launch the app (iCloud optional).
2. Create a manual booking from the + menu or trip detail.
3. Optional: enable Calendar/Reminders in Settings → Mehr.

Background mode "remote-notification" is used only for CloudKit silent sync mirroring, not for user-visible push notifications.

No in-app purchases. No Reisen user account. CloudKit uses the reviewer's iCloud account if signed in.
```

## CloudKit (Developer Portal)

- Container `iCloud.de.reisen.Reisen` an **drei** App-IDs binden: macOS, Store-iOS (`de.reisen.Reisen.ios`), Private-iOS (`de.reisen.Reisen.ios.private`).
- Distribution-Builds: **Production**-Umgebung (Release-Entitlements `aps-environment` = `production`).

## Build hochladen

```bash
bash ./Scripts/ios-archive-appstore.sh
```

Erzeugt Archive + exportiertes IPA unter `.build/ReiseniOS-ipa/`. Das Script prüft via `Scripts/ios-verify-binary-isolation.sh`, dass das Store-Binary **weder** Provider-Adapter **noch** Session-Probe-Infrastruktur (`ReisenProviders`) enthält. Upload via Transporter oder App Store Connect.

## Architektur (Zwei-App-Strategie)

| App | Bundle-ID | Provider-Abruf | Distribution |
|-----|-----------|----------------|--------------|
| Reisen (Store) | `de.reisen.Reisen.ios` | Nein | App Store |
| Reisen Sync (Private) | `de.reisen.Reisen.ios.private` | Ja | Ad Hoc / Internal TestFlight |
| Reisen (Mac) | `de.reisen.Reisen` | Ja | Developer ID / direkt |

Module: `ReisenProviders`, Provider-**Adapter** (`ReisenCheck24`, `ReisenBookingCom`, …) und `ReisenProviderSync` werden **nicht** vom Store-Target verlinkt. Store nutzt `ReisenAppCore` + `ReisenSharedUI` + Domain/Data (iCloud, manuelle Buchungen, Kalender/Erinnerungen). CI prüft Release-Binaries via `Scripts/ios-build-release-check.sh` — verboten sind u. a. Adapter-API-Strings, Session-Probe-URLs (Opodo/Traveloka) und Provider-Symbole (siehe `Scripts/ios-verify-binary-isolation.sh`).
