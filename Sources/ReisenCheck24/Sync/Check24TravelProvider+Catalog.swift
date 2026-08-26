import Foundation
import WebKit

extension Check24TravelProvider {
    enum BookingURLGroup {
        case hotel
        case nonHotel
    }

    func fetchActivity(using webView: WKWebView) async throws -> ParsedActivity {
        onProgress?("Lade Aktivitäten (API)…")
        do {
            let activitiesJSON = try await fetchActivitiesJSON(using: webView)
            return try parseCatalogAllowingEmpty(activitiesJSON)
        } catch {
            onProgress?("Activities-API fehlgeschlagen, nutze HTML-Snapshot…")
            let currentHTML = try await snapshotHTML(from: webView)
            return try parseCatalogAllowingEmpty(currentHTML.html)
        }
    }

    /// Leerer Katalog ist ein gültiges Ergebnis (wie Booking.com/Airbnb), kein Parser-Fehler.
    func parseCatalogAllowingEmpty(_ text: String) throws -> ParsedActivity {
        do {
            return try ActivityListParser().parseActivityListHTML(text)
        } catch Check24ParseError.noBookingDatesFound, Check24ParseError.noBookingLinkFound {
            return ParsedActivity(bookings: [], cancellationDeadlines: [])
        }
    }

    func maybeApplyInitialPolicySnapshot(
        from webView: WKWebView,
        into deadlinesByBookingURL: inout [String: [ParsedCancellationDeadline]]
    ) async throws {
        if let currentHTML = try? await snapshotHTML(from: webView) {
            let initialPolicy = CancellationPolicyParser().parseCancellationPolicy(from: currentHTML.html)
            if !initialPolicy.deadlines.isEmpty {
                deadlinesByBookingURL[currentHTML.url.absoluteString] = initialPolicy.deadlines
            }
        }
    }

    func bookingsWithURL(
        for group: BookingURLGroup,
        in activity: ParsedActivity
    ) -> [(ParsedBooking, URL)] {
        switch group {
        case .hotel:
            return activity.bookings.compactMap { booking -> (ParsedBooking, URL)? in
                guard booking.type == .hotel else { return nil }
                guard let urlString = booking.externalUrl, let url = URL(string: urlString) else { return nil }
                guard isHotelBookingDetailURL(url) else { return nil }
                return (booking, url)
            }
        case .nonHotel:
            return activity.bookings.compactMap { booking -> (ParsedBooking, URL)? in
                guard booking.type == .flight || booking.type == .ferry else { return nil }
                guard let urlString = booking.externalUrl, let url = URL(string: urlString) else { return nil }
                guard isNonHotelBookingDetailURL(url) else { return nil }
                return (booking, url)
            }
        }
    }
}
