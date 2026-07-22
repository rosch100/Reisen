# Reisen

macOS-App zur Verwaltung von Flug- und Hotelbuchungen. Datenquellen sind austauschbare **Provider** (aktuell: CHECK24). Persistenz ist **kanonisch** (Domain-Entities) mit SwiftData als Adapter.

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
2. Bei Check24 anmelden
3. **Jetzt synchronisieren**

## Hinweise zu CHECK24

CHECK24 ist ein Vermittlungs-/Vergleichsportal. Automatisiertes Auslesen ist rechtlich/technisch sensibel: Der Sync ist für **lokale, persönliche Nutzung** gedacht und speichert keine Credentials im Klartext (Session nur im WebView-Cookie-Store).

## Lizenz (nicht-kommerziell)

Dieses Projekt ist unter **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)** lizenziert.

Der Code darf geteilt und angepasst werden, **aber nicht** für kommerzielle Zwecke verwendet werden.

Lizenz-Links:
- Kurzfassung: https://creativecommons.org/licenses/by-nc/4.0/
- Vollständiger Legal Code: https://creativecommons.org/licenses/by-nc/4.0/legalcode

## Weiterer Ausbau

- Weitere Provider: `TravelProvider` + optional `GapDeepLinkBuilding` registrieren
- iOS/iPadOS: Shared-Module wiederverwenden, App-Target und WebView-UI portieren
