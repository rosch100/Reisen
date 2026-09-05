import Foundation
import ReisenDomain

/// Parses Booking.com Trip-XP GraphQL (`getTrips` + `singleTripTimeline`) into catalog drafts.
public struct BookingComTripsGraphQLParser: Sendable {
    public init() {}

    public func parseTimeline(from json: String) throws -> [ProviderBookingDraft] {
        let envelope: TimelineEnvelope = try decodeGraphQL(json)
        let timeline = envelope.data?.singleTripTimelineQueries?.singleTripTimeline
        let groups = timeline?.timelineGroups ?? []
        if groups.isEmpty, let failure = graphQLFailure(envelope.errors) {
            throw failure
        }

        let tripTitle = timeline?.trip?.title
        let tripCanceled = timeline?.trip?.canceled == true
        var bookings: [ProviderBookingDraft] = []
        for group in groups {
            for item in group.tripItems ?? [] {
                guard let reservation = item.reservation else { continue }
                if let draft = draft(
                    from: reservation,
                    tripTitle: tripTitle,
                    tripCanceled: tripCanceled
                ) {
                    bookings.append(draft)
                }
            }
        }

        return BookingComParsing.dedupeByExternalURL(bookings)
    }
}

public enum BookingComTripsGraphQLParserError: LocalizedError, Sendable, Equatable {
    case invalidJSON
    case graphQLErrors(String?)
    case tripsListError

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Booking.com GraphQL-Antwort konnte nicht gelesen werden."
        case .graphQLErrors(let detail):
            if let detail, !detail.isEmpty {
                return "Booking.com GraphQL meldete Fehler: \(detail)"
            }
            return "Booking.com GraphQL meldete Fehler."
        case .tripsListError:
            return "Booking.com Trip-Liste konnte nicht geladen werden."
        }
    }
}
