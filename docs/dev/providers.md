# Unterstützte Anbieter (Sync)

SSOT im Code: [`ProviderID.syncProviderIDs`](../../Sources/ReisenDomain/Entities/ProviderID.swift) und [`ProviderSyncBootstrap.makeProviderRegistry()`](../../Sources/ReisenProviderSync/ProviderSyncBootstrap.swift).

| Anbieter | Modul | Typische Buchungen | Impl-Spec / Notizen |
|----------|-------|-------------------|---------------------|
| Check24 | ReisenCheck24 | Flug, Hotel, Fähre, Mietwagen (`rentalcar` → [mietwagen.check24.de](https://mietwagen.check24.de/) → `.carRental`), … | productKey-basiert; [Audit](check24-productkey-audit.md) |
| Opodo | ReisenOpodo | Flug, Hotel | GraphQL `getTrips`; HTML nur wenn GraphQL leer; Upsell ignoriert |
| Booking.com | ReisenBookingCom | Flug, Hotel, Flughafentaxi; Attractions/Car schema-bekannt | GraphQL V1 + HTML-Fallback; [Audit](bookingcom-mytrips-audit.md) |
| Airbnb | ReisenAirbnb | Unterkünfte, Erlebnisse | [Experiences](airbnb-experiences-impl-spec.md); Stay-Hints aus `house_rules` / `house_manual` |
| GetYourGuide | ReisenGetYourGuide | Erlebnisse / Touren | [Impl-Spec](getyourguide-impl-spec.md) |
| Traveloka | ReisenTraveloka | Hotel, Flug, Erlebnisse, Mietwagen, … | [Impl-Spec](traveloka-impl-spec.md) |
| billiger-mietwagen.de | ReisenBilligerMietwagen | Mietwagen (FLOYT) | [Impl-Spec](billiger-mietwagen-impl-spec.md) |

**Manuell:** Buchungen ohne Portal (`ProviderID.manual`) — Flug, Hotel, Fähre, Erlebnis, Sonstiges.

## Neuen Anbieter hinzufügen

1. SPM-Target + `TravelProvider`-Implementierung
2. Eintrag in `ProviderID.syncProviderIDs` und `ProviderSyncBootstrap.makeProviderRegistry()`
3. Logo/UI-Liste (macOS + iOS)
4. Tests + ggf. Fixture unter `docs/fixtures/provider-research/`

Kandidaten-Recherche: [`API_Research_Provider_Candidates.md`](../API_Research_Provider_Candidates.md)

## Haftungsausschluss

Reisen ist **nicht** mit den genannten Anbietern verbunden. Login erfolgt mit dem Nutzerkonto des jeweiligen Portals in einer eingebetteten Web-Ansicht.
