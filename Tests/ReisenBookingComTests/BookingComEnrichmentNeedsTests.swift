import Foundation
import Testing
import ReisenBookingCom
import ReisenDomain

private final class UnusedProviderSession: ProviderSession {}

@MainActor
@Test("Booking.com needsDraftEnrichment folgt DraftEnrichmentNeeds")
func bookingComNeedsDraftEnrichmentFollowsDomainGate() {
    let provider = BookingComTravelProvider()
    let drafts = [
        enrichmentDraft(
            .carRental,
            locationFrom: "A",
            locationTo: "B",
            operatorName: "Rent"
        ),
        enrichmentDraft(.activity),
        enrichmentDraft(.other, locationFrom: "DPS", operatorName: "Transfer"),
        enrichmentDraft(.hotel, status: .unknown),
        enrichmentDraft(.flight, status: .confirmed),
    ]
    for draft in drafts {
        #expect(
            provider.needsDraftEnrichment(draft: draft, requiresDeadlines: false)
                == DraftEnrichmentNeeds.shouldEnrich(draft, requiresDeadlines: false)
        )
    }
}

@MainActor
@Test("Booking.com enrichBooking lädt keine Hotel-Confirm für Mietwagen")
func bookingComEnrichBookingSkipsCarWithoutSession() async throws {
    let provider = BookingComTravelProvider()
    let ref = ProviderBookingRef(
        externalUrl: "https://cars.booking.com/confirmation/fixture",
        bookingType: .carRental
    )
    let enrichment = try await provider.enrichBooking(
        session: UnusedProviderSession(),
        ref: ref
    )
    #expect(enrichment.guestHints == nil)
    #expect(enrichment.rateDetails == nil)
}

private func enrichmentDraft(
    _ bookingType: BookingType,
    locationFrom: String? = nil,
    locationTo: String? = nil,
    operatorName: String? = nil,
    status: BookingStatus = .confirmed
) -> ProviderBookingDraft {
    let start = Date()
    return ProviderBookingDraft(
        provider: .booking,
        bookingType: bookingType,
        startAt: start,
        endAt: start.addingTimeInterval(3600),
        locationFrom: locationFrom,
        locationTo: locationTo,
        operatorName: operatorName,
        status: status
    )
}
