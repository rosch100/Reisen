import Foundation
import Testing
import ReisenProviderSync
import ReisenDomain

@Test @MainActor func providerSyncBootstrapRegistry_matchesSyncProviderIDsSSOT() {
    let registry = ProviderSyncBootstrap.makeProviderRegistry()
    #expect(registry.syncProviderIDs == ProviderID.syncProviderIDs)
}

@Test @MainActor func providerNeedsDraftEnrichment_followsFieldGapsOnly() throws {
    let registry = ProviderSyncBootstrap.makeProviderRegistry()
    func provider(_ id: ProviderID) throws -> any TravelProvider {
        try #require(registry.provider(id: id))
    }

    let completeHotel = ProviderBookingDraft(
        provider: .booking,
        bookingType: .hotel,
        title: "Hotel",
        externalUrl: "https://secure.booking.com/confirmation",
        startAt: Date(),
        endAt: Date(),
        locationToAddress: "Street 1",
        status: .confirmed,
        deadlines: [
            CancellationDeadline(deadlineAt: Date(), policyText: "Free", isFreeCancellation: true),
        ],
        rateDetails: BookingRateDetails(roomCategory: "Double"),
        hotelCheckInMinutes: 15 * 60,
        hotelCheckOutMinutes: 11 * 60
    )

    // Traveloka braucht zusätzlich GuestHints — separat unten.
    for id in [ProviderID.airbnb, .booking, .getYourGuide, .opodo, .check24, .billigerMietwagen] {
        #expect(
            try provider(id).needsDraftEnrichment(
                draft: completeHotel,
                requiresDeadlines: false
            ) == false
        )
    }

    var travelokaHotel = completeHotel
    travelokaHotel.provider = .traveloka
    #expect(
        try provider(.traveloka).needsDraftEnrichment(
            draft: travelokaHotel,
            requiresDeadlines: false
        ) == true
    )
    travelokaHotel.guestHints = [
        BookingGuestHint(
            title: "Hausregeln",
            detail: "Example policy",
            sourceKey: "traveloka:property_policy",
            providerRaw: ProviderID.traveloka.rawValue
        ),
    ]
    #expect(
        try provider(.traveloka).needsDraftEnrichment(
            draft: travelokaHotel,
            requiresDeadlines: false
        ) == false
    )

    let catalogCarRental = ProviderBookingDraft(
        provider: .billigerMietwagen,
        bookingType: .carRental,
        title: "Berlin → München",
        externalUrl: "https://www.billiger-mietwagen.de/reservation/account/bookings/<REDACTED-UUID>",
        startAt: Date(),
        endAt: Date(),
        locationFrom: "Berlin",
        locationTo: "München",
        operatorName: "Thrifty",
        status: .confirmed
    )
    #expect(
        try provider(.billigerMietwagen).needsDraftEnrichment(
            draft: catalogCarRental,
            requiresDeadlines: false
        )
    )
    var enrichedCarRental = catalogCarRental
    enrichedCarRental.locationFromAddress = "Street 1, Berlin"
    enrichedCarRental.locationToAddress = "Street 2, München"
    #expect(
        try provider(.billigerMietwagen).needsDraftEnrichment(
            draft: enrichedCarRental,
            requiresDeadlines: false
        ) == false
    )

    var unknownStatus = completeHotel
    unknownStatus.status = .unknown
    #expect(
        try provider(.booking).needsDraftEnrichment(
            draft: unknownStatus,
            requiresDeadlines: false
        )
    )
}
