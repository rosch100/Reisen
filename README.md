# Reisen

macOS-App zur Verwaltung von Flug- und Hotelbuchungen. Datenquellen sind austauschbare **Provider**; Persistenz ist **kanonisch** (Domain-Entities) mit SwiftData als Adapter.

Unterstützte Provider (Sync/Session):
- `Check24`
- `Opodo`
- `Booking.com`
- `Airbnb` (Stay/Hotel-artige Buchungen, Experiences i. d. R. als `.other`)

## Architektur

```
ReisenDomain      Entities, Ports, Use Cases, reine Services
ReisenData        SwiftData (@Model), VersionedSchema, Repositories, Mapper
ReisenProviders   TravelProvider, ProviderRegistry, Deep-Link-Ports
ReisenCheck24     Check24-Adapter (Session, API/HTML-Parser → Domain-Drafts)
Reisen (App)      SwiftUI, SyncStore, Platform (Notifications, EventKit, WebView-UI)
```

Shared Domain/Data/Providers sind für **macOS 14+ und iOS 17+** vorbereitet; die App-UI ist derzeit macOS-only.

### Sync-Flow

1. Login im eingebetteten `WKWebView` (Provider-Session)
2. `TravelProvider.fetchCatalog` lädt Activities (Check24: Session-API) und optional Detailseiten
3. `SyncProviderBookings` upsertet kanonische `Booking`-Entities über Repositories
4. Optionale Side Effects: lokale Notifications, EventKit

Keine stillen Store-Fallbacks: bei Schema-/Store-Fehlern zeigt die App einen Reset-Dialog.

## Quickstart

```bash
./Scripts/run-app.sh
```

1. Seitenleiste **Anmelden & Sync**
2. Provider aktivieren und im eingebetteten `WKWebView` anmelden
3. **Jetzt synchronisieren**

## CI (Continuous Integration)

[![CI](https://github.com/rosch100/Reisen/actions/workflows/ci.yml/badge.svg)](https://github.com/rosch100/Reisen/actions/workflows/ci.yml)

Für PRs und Pushs auf `master` läuft die CI automatisch:
- `swift build --build-tests`
- `swift test` über `bash ./Scripts/ci-test.sh`

Lokale CI-parität:
```bash
bash ./Scripts/ci-test.sh
```

## Vollständige Funktionalität (Kurzüberblick)

Beim Sync:
1. Lädt der ausgewählte Provider eine Katalog-Ansicht (Trips/Activities) via eingeloggter Web-Session.
2. Parsed Daten werden in die kanonische Domain-Struktur (`Booking`, `Trip`, `CancellationDeadline`, optional `BookingRateDetails`) überführt und persistent gespeichert.
3. Wenn vom Nutzer aktiviert: werden **Stornofristen** als lokale **Benachrichtigungen/Erinnerungen** geplant sowie optional **Kalenderereignisse** geschrieben (inkl. Zeitnormalisierung).

Hinweis: Der Sync ist für **lokale, persönliche Nutzung** gedacht und speichert keine Credentials im Klartext; Session-Cookies bleiben im WebView-Cookie-Store.

## Lizenz (nicht-kommerziell)

Dieses Projekt ist unter **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)** lizenziert.

Der Code darf geteilt und angepasst werden, **aber nicht** für kommerzielle Zwecke verwendet werden.

Lizenz-Links:
- Kurzfassung: https://creativecommons.org/licenses/by-nc/4.0/
- Vollständiger Legal Code: https://creativecommons.org/licenses/by-nc/4.0/legalcode

## Weiterer Ausbau

- Weitere Provider: `TravelProvider` + optional `GapDeepLinkBuilding` registrieren
- iOS/iPadOS: Shared-Module wiederverwenden, App-Target und WebView-UI portieren
