import ReisenAppCore
import ReisenAirbnb
import ReisenBookingCom
import ReisenCheck24
import ReisenDomain
import ReisenGetYourGuide
import ReisenOpodo
import ReisenProviders
import ReisenTraveloka
import ReisenBilligerMietwagen

/// Produktions-Registry für Private-iOS und macOS (nicht im App-Store-Binary).
@MainActor
public enum ProviderSyncBootstrap {
    /// Produktions-Registry; Reihenfolge und Inhalt folgen `ProviderID.syncProviderIDs`.
    public static func makeProviderRegistry() -> ProviderRegistry {
        let providersByID: [ProviderID: any TravelProvider] = [
            .check24: Check24TravelProvider(),
            .opodo: OpodoTravelProvider(),
            .booking: BookingComTravelProvider(),
            .airbnb: AirbnbTravelProvider(),
            .getYourGuide: GetYourGuideTravelProvider(),
            .traveloka: TravelokaTravelProvider(),
            .billigerMietwagen: BilligerMietwagenTravelProvider(),
        ]
        let providers = ProviderID.syncProviderIDs.compactMap { providersByID[$0] }
        precondition(
            providers.count == ProviderID.syncProviderIDs.count,
            "ProviderRegistry: fehlende Implementierung für \(Set(ProviderID.syncProviderIDs).subtracting(providers.map(\.id)))"
        )

        return ProviderRegistry(
            providers: providers,
            deepLinkBuilders: [
                Check24DeepLinkBuilder(),
                BookingComDeepLinkBuilder(),
                AirbnbDeepLinkBuilder(),
                GetYourGuideDeepLinkBuilder(),
                TravelokaDeepLinkBuilder(),
            ]
        )
    }
}
