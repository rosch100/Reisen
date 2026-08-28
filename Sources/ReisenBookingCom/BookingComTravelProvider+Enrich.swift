import Foundation
import ReisenDomain
import ReisenProviders

@MainActor
extension BookingComTravelProvider {
    public func needsDraftEnrichment(
        draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool {
        switch draft.bookingType {
        case .hotel, .flight:
            return DraftEnrichmentNeeds.shouldEnrich(draft, requiresDeadlines: requiresDeadlines)
        default:
            return false
        }
    }

    public func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        switch ref.bookingType {
        case .flight:
            return try await enrichFlightStay(session: session, ref: ref)
        case .hotel:
            return try await enrichHotelStay(session: session, ref: ref)
        default:
            return emptyEnrichment(bookingType: ref.bookingType)
        }
    }

    private func enrichFlightStay(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        let webView = try webView(from: session)
        guard let url = URL(string: ref.externalUrl) else {
            throw BookingComProviderError.catalogNotFound
        }
        return try await enrichFlight(using: webView, confirmationURL: url)
    }

    private func enrichHotelStay(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        let webView = try webView(from: session)
        onProgress?("Lade Buchungsdetails…")
        guard let confirmationURL = BookingComParsing.normalizedHotelConfirmationURL(ref.externalUrl)
            .flatMap(URL.init(string:)) else {
            return emptyEnrichment(bookingType: .hotel)
        }
        let html = try await loadHotelConfirmationHTML(using: webView, url: confirmationURL)
        let deadlines = BookingComCancellationDeadlineParser().parseDeadlines(
            from: html,
            hotelOffsetSeconds: ref.hotelOffsetSeconds
        )
        let rateDetails = BookingComHotelConfirmationParser().parseRateDetails(from: html)
        let guestHints = BookingComGuestHintParser().parse(from: html)
        return DraftAssembler.enrichment(
            from: ProviderBookingFacts(
                provider: .booking,
                bookingType: .hotel,
                deadlines: deadlines,
                rateDetails: rateDetails,
                hotelOffsetSeconds: ref.hotelOffsetSeconds,
                guestHints: guestHints
            )
        )
    }

    private func emptyEnrichment(bookingType: BookingType) -> ProviderBookingEnrichment {
        DraftAssembler.enrichment(
            from: ProviderBookingFacts(provider: .booking, bookingType: bookingType)
        )
    }
}
