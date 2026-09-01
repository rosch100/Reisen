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
        #expect(ProviderCancellationLinkPolicy.mode(provider: .manual, bookingType: type) == .distinctURL)
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
    typealias ExpectedMode = (
        bookingType: BookingType,
        mode: ProviderCancellationLinkMode
    )
    func expectedModes(_ mode: ProviderCancellationLinkMode) -> [ExpectedMode] {
        BookingType.allCases.map { (bookingType: $0, mode: mode) }
    }

    let expectations: [(provider: ProviderID, modes: [ExpectedMode])] = [
        (.traveloka, expectedModes(.distinctURL)),
        (
            .airbnb,
            BookingType.allCases.map {
                (bookingType: $0, mode: $0 == .activity ? .distinctURL : .none)
            }
        ),
        (.getYourGuide, expectedModes(.inPageOnOpen)),
        (.billigerMietwagen, expectedModes(.sessionBoundDistinct)),
        (.check24, expectedModes(.none)),
        (.opodo, expectedModes(.none)),
        (.booking, expectedModes(.none)),
    ]

    #expect(expectations.count == ProviderID.syncProviderIDs.count)
    #expect(Set(expectations.map(\.provider)) == Set(ProviderID.syncProviderIDs))

    for expectation in expectations {
        for expected in expectation.modes {
            #expect(
                ProviderCancellationLinkPolicy.mode(
                    provider: expectation.provider,
                    bookingType: expected.bookingType
                ) == expected.mode
            )
        }
    }
}
