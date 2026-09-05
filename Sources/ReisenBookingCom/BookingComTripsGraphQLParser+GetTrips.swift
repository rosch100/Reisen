import Foundation
import ReisenDomain

extension BookingComTripsGraphQLParser {
    public func parseTripIDs(fromGetTripsJSON json: String) throws -> [String] {
        let list = try decodeGetTripsList(from: json)
        // canceled:true weglassen — kein Timeline-Fetch. Absenz-Reconcile in
        // SyncProviderBookings.deleteProviderBookings(keepingExternalURLs:) entfernt
        // zuvor syncte confirmed-Buchungen, die nicht mehr im aktiven Katalog sind
        // (gleiche Semantik wie DraftAssembler-Drop von CANCELLED).
        return list.trips.compactMap { trip -> String? in
            guard trip.canceled != true else { return nil }
            guard let id = trip.id, !id.isEmpty else { return nil }
            return id
        }
    }

    public func parsePaginationToken(fromGetTripsJSON json: String) throws -> String? {
        let list = try decodeGetTripsList(from: json)
        let token = list.nextPageData?.paginationToken
        guard let token, !token.isEmpty else { return nil }
        return token
    }

    func decodeGetTripsList(from json: String) throws -> GetTripsListPayload {
        let envelope: GetTripsEnvelope = try decodeGraphQL(json)
        guard let getTrips = envelope.data?.tripsQueries?.getTrips else {
            throw graphQLFailure(envelope.errors) ?? BookingComTripsGraphQLParserError.invalidJSON
        }
        if getTrips.typeName == "TripsListError" {
            throw BookingComTripsGraphQLParserError.tripsListError
        }
        let trips = getTrips.trips ?? []
        if trips.isEmpty, let failure = graphQLFailure(envelope.errors) {
            throw failure
        }
        return GetTripsListPayload(
            trips: trips,
            nextPageData: getTrips.nextPageData
        )
    }
}
