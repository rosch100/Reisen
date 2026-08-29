# App Store Connect — Checkliste (ReiseniOS, Store)

Technische Voraussetzungen im Repo sind in [apple-signing.md](apple-signing.md) und `Scripts/ios-archive-appstore.sh` beschrieben. Diese Checkliste gilt für die **App-Store-Variante** (`de.reisen.Reisen.ios`) — **ohne** Provider-Abruf im Binary.

Vollständiger Provider-Sync: separate Private-iOS-App, siehe [ios-private-distribution.md](ios-private-distribution.md).

## App-Informationen

| Feld | Wert / Hinweis |
|------|----------------|
| Name (App Store Connect) | **Reisen Buchungen** (Listung, max. 30 Zeichen). Home-Screen bleibt `CFBundleDisplayName` = `Reisen` (`Apps/ReiseniOS/Info.plist`). Bundle-ID unverändert. |
| Bundle-ID | `de.reisen.Reisen.ios` (siehe `project.yml` → `ReiseniOS`) |
| Kategorie | Reisen |
| Privacy Policy URL (DE) | `https://rosch100.github.io/Reisen/privacy.html` (`LegalURLs.privacyPolicyGerman`) |
| Privacy Policy URL (EN) | `https://rosch100.github.io/Reisen/privacy.en.html` (`LegalURLs.privacyPolicyEnglish`; Redirect auf `en/privacy.html`) |
| Support Email | `reisenapp100@gmail.com` (`GitHubRepository.feedbackEmail`) |
| Support URL (DE) | `https://rosch100.github.io/Reisen/support.html` (`LegalURLs.supportGerman`) |
| Support URL (EN) | `https://rosch100.github.io/Reisen/support.en.html` (`LegalURLs.supportEnglish`; Redirect auf `en/support.html`) |
| Übersicht / beide Sprachen | `https://rosch100.github.io/Reisen/` — zweisprachige **Produktseite** (DE: `/`, EN: `/en/`); Legal: Datenschutz, Support, Impressum |
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

Abgleich mit `Apps/ReiseniOS/PrivacyInfo.xcprivacy` (Store-Variante **ohne** Provider-E-Mail):

| Datentyp | Verknüpft | Tracking | Zweck |
|----------|-----------|----------|-------|
| Name (Mitreisende) | Ja | Nein | App-Funktionalität |
| Geburtsdatum (Mitreisende, optional) | Ja | Nein | App-Funktionalität |
| Physische Adresse (Unterkunft/Station) | Ja | Nein | App-Funktionalität |
| Nutzer-ID (iCloud / CloudKit) | Ja | Nein | App-Funktionalität |
| Nutzerinhalte (`OtherUserContent`: Buchungen, Kalendertexte) | Ja | Nein | App-Funktionalität |
| Kundensupport (Feedback-Issues) | Ja | Nein | App-Funktionalität |
| Crash-Daten (Opt-in Auto-Report) | Ja | Nein | App-Funktionalität |
| Sonstige Diagnosedaten (OS, Gerät, Locale, Zeitzone, RAM/Disk/Thermal, Sync-Log-Auszug) | Ja | Nein | App-Funktionalität |

Nicht als „Collected“ angeben (verlassen das Gerät nicht bzw. fehlen in der Store-App):

- **Provider-E-Mail/Kennwort** — Store-App hat keinen Provider-Login
- **Installierte Provider-Apps** (`canOpenURL`) — nur Private-iOS

Required Reason APIs im Manifest: UserDefaults `CA92.1`, File Timestamp `C617.1` (App-Container / SwiftData).

Zusätzlich in ASC angeben, falls gefragt (nicht im Privacy-Manifest):

- **Kalender/Erinnerungen** — Full Access, Zweck Stornofristen aktualisieren/entfernen
- **MapKit-Geocoding** — keine Nutzer-GPS-Position, nur Ortsnamen/IATA

**Nicht** angeben (Store-App): uneingeschränkter Webzugriff in OTA-WebViews.

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

Calendar and Reminders use full access so cancellation-deadline events can be created, updated, and removed. Both are opt-in in Settings.

No in-app purchases. No Reisen user account. CloudKit uses the reviewer's iCloud account if signed in.
```

## CloudKit (Developer Portal)

- Container `iCloud.de.reisen.Reisen` an **drei** App-IDs binden: macOS, Store-iOS (`de.reisen.Reisen.ios`), Private-iOS (`de.reisen.Reisen.ios.private`).
- Distribution-Builds: **Production**-Umgebung (Release-Entitlements `aps-environment` = `production`).

## App-Eintrag in App Store Connect

Signing und IPA brauchen nur die **App-ID** im Developer Portal. `altool --validate-app` und der Upload brauchen zusätzlich den **App-Eintrag** unter [My Apps](https://appstoreconnect.apple.com/apps):

1. Zuerst unter [My Apps](https://appstoreconnect.apple.com/apps) prüfen, ob **dieses** Team schon einen iOS-Eintrag für `de.reisen.Reisen.ios` hat — dann diesen nutzen, keine zweite App anlegen.
2. Sonst **+** → New App → Plattform **iOS**, Name **Reisen Buchungen**, Bundle-ID **`de.reisen.Reisen.ios`**, SKU z. B. `reisen-ios`, Sprache Deutsch.
3. Icon-Name auf dem Gerät bleibt `Reisen` (`CFBundleDisplayName`). Der App-Store-Name „Reisen“ ist vergeben; Trademark-Claim nur mit eingetragener Marke.

Ohne diesen Eintrag: `Unable to find Apple ID for Bundle ID 'de.reisen.Reisen.ios'`. Die numerische Apple-ID steht danach unter App Information; lokal optional `APP_STORE_CONNECT_APPLE_ID`, falls der API-Key die App nicht per Bundle-ID sieht.

## Build hochladen

```bash
bash ./Scripts/ios-archive-appstore.sh
```

Erzeugt Archive + exportiertes IPA unter `.build/ReiseniOS-ipa/`. Das Script prüft via `Scripts/ios-verify-binary-isolation.sh`, dass das Store-Binary **weder** Provider-Adapter **noch** Session-Probe-Infrastruktur (`ReisenProviders`) enthält. Upload via Transporter oder App Store Connect.

Vor dem Upload: manueller Workflow **App Store Check** (Store-IPA-Archive, Isolation, Apple ITMS-Validierung, [`app-store-check.md`](app-store-check.md)). Der Workflow prüft nicht die App-Store-Review-Guidelines.

## Architektur (Zwei-App-Strategie)

| App | Bundle-ID | Provider-Abruf | Distribution |
|-----|-----------|----------------|--------------|
| Reisen (Store) | `de.reisen.Reisen.ios` | Nein | App Store |
| Reisen Sync (Private) | `de.reisen.Reisen.ios.private` | Ja | Ad Hoc / Internal TestFlight |
| Reisen (Mac) | `de.reisen.Reisen` | Ja | Developer ID / direkt |

Module: `ReisenProviders`, Provider-**Adapter** (`ReisenCheck24`, `ReisenBookingCom`, …) und `ReisenProviderSync` werden **nicht** vom Store-Target verlinkt. Store nutzt `ReisenAppCore` + `ReisenSharedUI` + Domain/Data (iCloud, manuelle Buchungen, Kalender/Erinnerungen). CI prüft Release-Binaries auf PRs gegen `master` via `Scripts/ios-build-release-check.sh` — verboten sind u. a. Adapter-API-Strings, Session-Probe-URLs (Opodo/Traveloka) und Provider-Symbole (siehe `Scripts/ios-verify-binary-isolation.sh`).
