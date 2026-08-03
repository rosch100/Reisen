import Foundation
import ReisenDomain
import ReisenProviders

@MainActor
extension BookingComTravelProvider {
    public func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        let webView = try webView(from: session)
        guard let url = URL(string: ref.externalUrl) else {
            throw BookingComProviderError.catalogNotFound
        }

        if ref.bookingType == .flight {
            return try await enrichFlight(using: webView, confirmationURL: url)
        }

        onProgress?("Lade Buchungsdetails…")
        guard let confirmationURL = BookingComParsing.normalizedHotelConfirmationURL(ref.externalUrl)
            .flatMap(URL.init(string:)) else {
            return ProviderBookingEnrichment()
        }
        let html = try await loadHotelConfirmationHTML(using: webView, url: confirmationURL)
        let deadlines = BookingComCancellationDeadlineParser().parseDeadlines(
            from: html,
            hotelOffsetSeconds: ref.hotelOffsetSeconds
        )
        let rateDetails = BookingComHotelConfirmationParser().parseRateDetails(from: html)
        return ProviderBookingEnrichment(
            deadlines: deadlines,
            rateDetails: rateDetails,
            hotelOffsetSeconds: ref.hotelOffsetSeconds
        )
    }
}
