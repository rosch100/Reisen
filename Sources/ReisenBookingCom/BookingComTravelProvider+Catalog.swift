import Foundation
import ReisenDomain
import ReisenProviders

@MainActor
extension BookingComTravelProvider {
    public func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog {
        let webView = try webView(from: session)

        onProgress?("Lade My Trips (session-gebunden)…")
        let myTripsHTML = try await loadMyTripsHTML(using: webView)
        let htmlTripIDs = BookingComParsing.tripIDsFromMyTripsHTML(myTripsHTML)

        onProgress?("Lade Buchungen (GraphQL)…")
        let graphQL = await attemptGraphQLCatalog(
            using: webView,
            myTripsHTML: myTripsHTML,
            preferredTripIDs: htmlTripIDs
        )
        if case .bookings(let bookings) = graphQL {
            return ProviderCatalog(bookings: bookings)
        }

        let lastGraphQLError = graphQLError(from: graphQL)
        if let authError = lastGraphQLError as? AuthenticatedFetchError,
           AuthenticatedSessionGuard.isUnauthorized(authError) {
            throw BookingComProviderError.sessionNotEstablished
        }
        if let sessionError = lastGraphQLError as? BookingComProviderError {
            switch sessionError {
            case .sessionNotEstablished, .sessionTokensMissing:
                throw sessionError
            case .catalogNotFound:
                break
            }
        }
        let fallback = try fetchCatalogFallbackHTML(htmlTripIDs: htmlTripIDs, myTripsHTML: myTripsHTML)
        switch fallback {
        case .bookings(let bookings):
            return ProviderCatalog(bookings: bookings)
        case .none:
            break
        }

        if let lastGraphQLError {
            throw lastGraphQLError
        }
        throw BookingComProviderError.catalogNotFound
    }

    func graphQLError(from result: GraphQLAttemptResult) -> Error? {
        if case .error(let error) = result {
            onProgress?("GraphQL-Katalog fehlgeschlagen, nutze HTML-Fallback…")
            return error
        }
        return nil
    }
}
