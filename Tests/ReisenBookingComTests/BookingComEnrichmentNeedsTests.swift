import Foundation
import Testing
import ReisenBookingCom
import ReisenDomain

private final class UnusedProviderSession: ProviderSession {}

@MainActor
@Test("Booking.com Enrichment nur für Hotel und Flug")
func bookingComNeedsDraftEnrichmentOnlyHotelAndFlight() {
    let provider = BookingComTravelProvider()
    let car = enrichmentDraft(
        .carRental,
        locationFrom: "A",
        locationTo: "B",
        operatorName: "Rent"
    )
    #expect(DraftEnrichmentNeeds.shouldEnrich(car, requiresDeadlines: false))
    #expect(!provider.needsDraftEnrichment(draft: car, requiresDeadlines: false))

    let activity = enrichmentDraft(.activity)
    #expect(DraftEnrichmentNeeds.shouldEnrich(activity, requiresDeadlines: false))
    #expect(!provider.needsDraftEnrichment(draft: activity, requiresDeadlines: false))

    let taxi = enrichmentDraft(.other, locationFrom: "DPS", operatorName: "Transfer")
    #expect(!provider.needsDraftEnrichment(draft: taxi, requiresDeadlines: false))

    let hotel = enrichmentDraft(.hotel, status: .unknown)
    #expect(provider.needsDraftEnrichment(draft: hotel, requiresDeadlines: false))
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
