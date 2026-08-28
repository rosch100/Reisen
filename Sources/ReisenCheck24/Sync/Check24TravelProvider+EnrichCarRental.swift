import Foundation
import WebKit
import ReisenDomain
import ReisenProviders

extension Check24TravelProvider {
    func enrichCarRentalDetail(
        webView: WKWebView,
        parsedBooking: ParsedBooking,
        bookingURL: URL,
        carRentalDetailByBookingKey: inout [String: ParsedCarRentalDetail]
    ) async throws {
        let alreadyThere = webView.url.map {
            Check24BookingDetailURL.isSameCarRentalBooking($0, bookingURL)
        } == true
        if !alreadyThere {
            try await load(url: bookingURL, in: webView)
        }

        guard await waitForCarRentalDetailReady(in: webView) else { return }

        let detailSnapshot = try await snapshotHTML(from: webView)
        guard let parsed = Check24CarRentalDetailParser.parse(from: detailSnapshot.html),
              let key = parsedBooking.identityKey else { return }
        carRentalDetailByBookingKey[key] = parsed
    }

    /// Wartet auf eingebettetes `CpInitial` / `rentalcarDetails` (Catalog + `enrichBooking`).
    func waitForCarRentalDetailReady(in webView: WKWebView) async -> Bool {
        await webView.waitForJavaScriptCondition(
            Check24CarRentalDetailParser.detailReadyJavaScript,
            timeoutSeconds: 8
        )
    }

    /// `html == nil` → leeres Enrichment (z. B. Wait-Timeout), ohne Snapshot/Parse.
    static func carRentalEnrichment(html: String?) -> ProviderBookingEnrichment {
        var facts = ProviderBookingFacts(provider: .check24, bookingType: .carRental)
        if let html {
            Check24CarRentalDetailParser.parse(from: html)?.apply(to: &facts)
        }
        return DraftAssembler.enrichment(from: facts)
    }
}
