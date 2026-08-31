import Testing
import ReisenDomain

@Test func providerCancellationLinkPolicy_wave1Modes() {
    #expect(
        ProviderCancellationLinkPolicy.mode(provider: .traveloka, bookingType: .hotel)
            == .distinctURL
    )
    #expect(
        ProviderCancellationLinkPolicy.mode(provider: .airbnb, bookingType: .activity)
            == .distinctURL
    )
    #expect(
        ProviderCancellationLinkPolicy.mode(provider: .airbnb, bookingType: .hotel)
            == .none
    )
    #expect(
        ProviderCancellationLinkPolicy.mode(provider: .getYourGuide, bookingType: .activity)
            == .inPageOnOpen
    )
    #expect(
        ProviderCancellationLinkPolicy.mode(provider: .billigerMietwagen, bookingType: .carRental)
            == .sessionBoundDistinct
    )
    for type in BookingType.allCases {
        #expect(ProviderCancellationLinkPolicy.mode(provider: .opodo, bookingType: type) == .none)
        #expect(ProviderCancellationLinkPolicy.mode(provider: .booking, bookingType: type) == .none)
        #expect(ProviderCancellationLinkPolicy.mode(provider: .check24, bookingType: type) == .none)
    }
}

@Test func providerCancellationLinkPolicy_requiresProviderSession() {
    #expect(ProviderCancellationLinkPolicy.requiresProviderSession(.inPageOnOpen))
    #expect(ProviderCancellationLinkPolicy.requiresProviderSession(.sessionBoundDistinct))
    #expect(!ProviderCancellationLinkPolicy.requiresProviderSession(.distinctURL))
    #expect(!ProviderCancellationLinkPolicy.requiresProviderSession(.none))
    #expect(
        ProviderCancellationLinkPolicy.requiresProviderSession(
            provider: .getYourGuide,
            bookingType: .activity
        )
    )
    #expect(
        ProviderCancellationLinkPolicy.requiresProviderSession(
            provider: .billigerMietwagen,
            bookingType: .carRental
        )
    )
    #expect(
        !ProviderCancellationLinkPolicy.requiresProviderSession(
            provider: .traveloka,
            bookingType: .hotel
        )
    )
}

@Test func providerCancellationLinkPolicy_coversAllSyncProviders() {
    for provider in ProviderID.syncProviderIDs {
        for type in BookingType.allCases {
            _ = ProviderCancellationLinkPolicy.mode(provider: provider, bookingType: type)
        }
    }
}
