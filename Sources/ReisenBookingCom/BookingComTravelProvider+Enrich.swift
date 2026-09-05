import Foundation
import ReisenDomain
import ReisenProviders
import ReisenDiagnostics

@MainActor
extension BookingComTravelProvider {
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
        let parser = BookingComCancellationDeadlineParser()
        if ref.hotelOffsetSeconds == nil, parser.hasFeeScheduleMarkup(html) {
            Self.recordHotelDeadlineSkipped(reason: "missing_hotel_offset")
        }
        let deadlines = parser.parseDeadlines(
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

    private static func recordHotelDeadlineSkipped(reason: String) {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .booking,
                        operation: "booking_com_enrich_hotel"
                    ),
                    component: "BookingComTravelProvider",
                    phase: "deadline",
                    event: "deadline_skipped",
                    result: .skipped,
                    reason: reason,
                    visibility: .publicDiagnostic
                )
            )
        }
    }

    private func emptyEnrichment(bookingType: BookingType) -> ProviderBookingEnrichment {
        DraftAssembler.enrichment(
            from: ProviderBookingFacts(provider: .booking, bookingType: bookingType)
        )
    }
}
