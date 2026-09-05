import Foundation
import ReisenProviders

@MainActor
extension BookingComTravelProvider {
    func loadMyTripsHTML(using webView: BookingComWebView) async throws -> String {
        // GraphQL im Browser-Kontext braucht die My-Trips-Seite (Referer/Capla/CSRF).
        try await ensureOnMyTripsPage(using: webView)

        if let html = try await evaluatedMyTripsHTML(using: webView) {
            return html
        }

        return try await fetchMyTripsHTMLAuthenticated(using: webView)
    }

    func ensureOnMyTripsPage(using webView: BookingComWebView) async throws {
        let onMyTrips = (webView.url?.host?.contains("booking.com") == true)
            && (webView.url?.path.localizedCaseInsensitiveContains("mytrips") == true)
        if !onMyTrips {
            try await NavigationAwaiter().load(Self.myTripsURL, in: webView)
        }
    }

    func evaluatedMyTripsHTML(using webView: BookingComWebView) async throws -> String? {
        guard let html = try await webView.evaluateJavaScriptStringAsync("document.documentElement.outerHTML"),
              html.contains("csrfToken") || html.contains("trip_id=") else {
            return nil
        }
        return html
    }

    func fetchMyTripsHTMLAuthenticated(using webView: BookingComWebView) async throws -> String {
        do {
            return try await webView.fetchAuthenticatedText(
                url: Self.myTripsURL,
                method: "GET",
                accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                referer: "https://secure.booking.com/",
                contentType: nil,
                body: nil,
                headers: [:],
                timeoutSeconds: 60
            )
        } catch let error as AuthenticatedFetchError where AuthenticatedSessionGuard.isUnauthorized(error) {
            throw BookingComProviderError.sessionNotEstablished
        } catch {
            throw BookingComProviderError.catalogNotFound
        }
    }
}
