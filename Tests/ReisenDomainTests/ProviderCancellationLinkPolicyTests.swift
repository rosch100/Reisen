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
            == .distinctURL
    )
    #expect(
        ProviderCancellationLinkPolicy.mode(provider: .getYourGuide, bookingType: .activity)
            == .inPageOnOpen
    )
    #expect(
        ProviderCancellationLinkPolicy.mode(provider: .billigerMietwagen, bookingType: .carRental)
            == .inPageOnOpen
    )
    #expect(
        ProviderCancellationLinkPolicy.mode(provider: .expedia, bookingType: .hotel)
            == .distinctURL
    )
    #expect(
        ProviderCancellationLinkPolicy.mode(provider: .expedia, bookingType: .carRental)
            == .inPageOnOpen
    )
    for type in BookingType.allCases {
        #expect(ProviderCancellationLinkPolicy.mode(provider: .manual, bookingType: type) == .distinctURL)
        #expect(ProviderCancellationLinkPolicy.mode(provider: .opodo, bookingType: type) == .inPageOnOpen)
        let bookingMode: ProviderCancellationLinkMode = type == .hotel ? .distinctURL : .none
        #expect(ProviderCancellationLinkPolicy.mode(provider: .booking, bookingType: type) == bookingMode)
        #expect(ProviderCancellationLinkPolicy.mode(provider: .check24, bookingType: type) == .distinctURL)
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
                let mode: ProviderCancellationLinkMode =
                    ($0 == .activity || $0 == .hotel) ? .distinctURL : .none
                return (bookingType: $0, mode: mode)
            }
        ),
        (.getYourGuide, expectedModes(.inPageOnOpen)),
        (.billigerMietwagen, expectedModes(.inPageOnOpen)),
        (.check24, expectedModes(.distinctURL)),
        (.opodo, expectedModes(.inPageOnOpen)),
        (
            .booking,
            BookingType.allCases.map {
                (bookingType: $0, mode: $0 == .hotel ? .distinctURL : .none)
            }
        ),
        (
            .expedia,
            BookingType.allCases.map {
                let mode: ProviderCancellationLinkMode
                switch $0 {
                case .hotel:
                    mode = .distinctURL
                case .carRental, .flight, .activity:
                    mode = .inPageOnOpen
                case .ferry, .train, .other:
                    mode = .none
                }
                return (bookingType: $0, mode: mode)
            }
        ),
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
