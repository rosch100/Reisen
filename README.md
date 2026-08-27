# Reisen

Persönliche Reiseverwaltung für **iPhone, iPad und Mac**. Flüge, Hotels, Erlebnisse und mehr an einem Ort — importiert von Buchungsportalen oder manuell eingetragen. Stornofristen im Blick, optional synchronisiert über iCloud.

Website: [rosch100.github.io/Reisen](https://rosch100.github.io/Reisen/)

## Unterstützte Anbieter (Sync)

Anmeldung mit deinem bestehenden Konto beim jeweiligen Portal; Reisen importiert die Buchungen. SSOT im Code: `ProviderID.syncProviderIDs` in [`Sources/ReisenDomain/Entities/ProviderID.swift`](Sources/ReisenDomain/Entities/ProviderID.swift).

| Anbieter | Typische Buchungen |
|----------|-------------------|
| **Check24** | Flug, Hotel, Fähre, Mietwagen, … |
| **Opodo** | Flug, Hotel |
| **Booking.com** | Flug, Hotel, Erlebnisse |
| **Airbnb** | Unterkünfte, Erlebnisse |
| **GetYourGuide** | Erlebnisse / Touren |
| **Traveloka** | Hotel, Flug, Erlebnisse, Mietwagen, … |

Zusätzlich: **manuelle Buchungen** (Flug, Hotel, Fähre, Erlebnis, Sonstiges) ohne Portal-Sync.

Reisen ist **nicht** mit diesen Anbietern verbunden — Login erfolgt direkt beim Portal in einer eingebetteten Web-Ansicht.

## Architektur

```
ReisenDomain         Entities, Ports, Use Cases, reine Services
ReisenData           SwiftData (@Model), VersionedSchema, Repositories, Mapper
ReisenProviders      TravelProvider, ProviderRegistry, Deep-Link-Ports
ReisenCheck24        Check24-Adapter
ReisenOpodo          Opodo-Adapter
ReisenBookingCom     Booking.com-Adapter
ReisenAirbnb         Airbnb-Adapter (Stays + Experiences)
ReisenGetYourGuide   GetYourGuide-Adapter
ReisenTraveloka      Traveloka-Adapter
ReisenAppCore        Bootstrap, SyncStore, EventKit/Reminder Side Effects
Reisen (macOS)       SwiftUI Composition Root + UI
ReiseniOS            Universal App (iPhone + iPad)
```

Shared Domain/Data/Providers und beide Apps unterstützen **macOS 26+** und **iOS 26+**. Gebaut wird mit **Xcode 27 / SDK 27**.

Details: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · Anbieter: [`docs/dev/providers.md`](docs/dev/providers.md)

### Sync-Flow

1. Login im eingebetteten `WKWebView` (Provider-Session)
2. `TravelProvider.fetchCatalog` lädt Buchungen über die eingeloggte Web-Session
3. `SyncProviderBookings` upsertet kanonische `Booking`-Entities über Repositories
4. Optionale Side Effects: lokale Notifications, EventKit

Keine stillen Store-Fallbacks: bei Schema-/Store-Fehlern zeigt die App einen Reset-Dialog.

## Quickstart

**macOS:**

```bash
./Scripts/run-app.sh
```

**iOS (Simulator):**

```bash
bash ./Scripts/generate-ios-project.sh
bash ./Scripts/ios-run.sh
```

1. Seitenleiste **Anmelden & Sync** (macOS) bzw. Tab **Sync** (iOS)
2. Anbieter aktivieren und im eingebetteten WebView anmelden
3. **Jetzt synchronisieren**

Cursor/Simulator-Workflow: [`docs/dev/ios-cursor.md`](docs/dev/ios-cursor.md)

## CI (Continuous Integration)

[![CI](https://github.com/rosch100/Reisen/actions/workflows/ci.yml/badge.svg)](https://github.com/rosch100/Reisen/actions/workflows/ci.yml)

Für PRs und Pushs auf `master` läuft die CI automatisch:
- `swift build --build-tests`
- `swift test` über `bash ./Scripts/ci-test.sh`

Lokale CI-Parität:

```bash
bash ./Scripts/ci-test.sh
```

## Funktionen (Kurzüberblick)

Beim Sync:
1. Lädt der ausgewählte Anbieter Buchungen über die eingeloggte Web-Session.
2. Geparste Daten werden in die kanonische Domain-Struktur (`Booking`, `Trip`, `CancellationDeadline`, optional `BookingRateDetails`) überführt und persistent gespeichert.
3. Wenn vom Nutzer aktiviert: **Stornofristen** als lokale **Benachrichtigungen/Erinnerungen** sowie optional **Kalenderereignisse**.

Der Sync ist für **lokale, persönliche Nutzung** gedacht; Session-Cookies bleiben im WebView-Cookie-Store. Optional (Opt-in): Zugangsdaten in der Geräte-Keychain.

## Öffentliche Issues (Fehler und Feedback)

Fehler in der App und Feedback in den Einstellungen können als **öffentliche** GitHub-Issues veröffentlicht werden: [github.com/rosch100/Reisen/issues](https://github.com/rosch100/Reisen/issues). Dafür ist **kein GitHub-Konto** nötig; ausgelieferte Apps (macOS-Release und iOS App Store) enthalten ein Issues-only-Token. Details: [docs/ci/github-issues-token.md](docs/ci/github-issues-token.md).

App-Store-Einreichung: [docs/ci/app-store-connect.md](docs/ci/app-store-connect.md) — Archive: `bash ./Scripts/ios-archive-appstore.sh`

## Lizenz (nicht-kommerziell)

Dieses Projekt ist unter **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)** lizenziert.

Der Code darf geteilt und angepasst werden, **aber nicht** für kommerzielle Zwecke verwendet werden.

Lizenz-Links:
- Kurzfassung: https://creativecommons.org/licenses/by-nc/4.0/
- Vollständiger Legal Code: https://creativecommons.org/licenses/by-nc/4.0/legalcode

## Weiterer Ausbau

- Weitere Anbieter: `TravelProvider` implementieren, in `AppBootstrap.makeProviderRegistry()` und `ProviderID.syncProviderIDs` registrieren
- Provider-Recherche: [`docs/API_Research_Provider_Candidates.md`](docs/API_Research_Provider_Candidates.md)
- Apple Developer (Signing, iCloud, Notarize): [docs/ci/apple-signing.md](docs/ci/apple-signing.md) — Setup: `bash ./Scripts/setup-apple-developer.sh`
