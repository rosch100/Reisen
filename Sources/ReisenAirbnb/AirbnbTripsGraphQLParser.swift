import Foundation
import ReisenDomain

/// Parser for Airbnb `TripListQuery` persisted-GraphQL responses.
///
/// We intentionally keep the decoded surface minimal: only the fields needed to create
/// `ProviderBookingDraft`s (IDs, dates, scheduled item type + confirmation codes).
enum AirbnbTripsGraphQLParser {
    static func parseTripList(from responseText: String) throws -> ProviderCatalog {
        let decoded = try AirbnbJSONDecoder.shared.decode(
            AirbnbTripListQueryEnvelope.self,
            from: Data(responseText.utf8)
        )

        let bookings = decoded
            .data.viewer.trips.edges
            .flatMap(\.node.scheduledItemsAsDrafts)

        return ProviderCatalog(bookings: bookings)
    }
}

private extension AirbnbTripNode {
    var scheduledItemsAsDrafts: [ProviderBookingDraft] {
        scheduledItems.edges.compactMap { edge in
            guard let details = edge.node.details else { return nil }

            // Stay has `stayReservation` with a confirmation code used by scheduled_events.
            if let stay = details.stayReservation, let confirmationCode = stay.confirmationCode, !confirmationCode.isEmpty {
                return ProviderBookingDraft(
                    provider: .airbnb,
                    bookingType: .hotel,
                    title: displayName,
                    confirmationCode: confirmationCode,
                    externalUrl: externalUrl(schedulableType: details.schedulableType, confirmationCode: confirmationCode),
                    startAt: startTime.dateTime,
                    endAt: endTime.dateTime,
                    locationTo: displayName,
                    locationToAddress: nil,
                    status: Self.mapStatus(tripStatus: status, reservationStatus: stay.status),
                    deadlines: [],
                    passengers: []
                )
            }

            if let activity = details.activityReservation, let confirmationCode = activity.confirmationCode, !confirmationCode.isEmpty {
                let guestCount = travelerCapacity?.numberOfAdults
                return ProviderBookingDraft(
                    provider: .airbnb,
                    bookingType: .activity,
                    // TripList `displayName` is the location, not the experience title (see enrichment).
                    title: nil,
                    confirmationCode: confirmationCode,
                    externalUrl: externalUrl(schedulableType: details.schedulableType, confirmationCode: confirmationCode),
                    startAt: startTime.dateTime,
                    endAt: endTime.dateTime,
                    locationTo: displayName,
                    locationToAddress: nil,
                    status: Self.mapStatus(tripStatus: status, reservationStatus: activity.status),
                    deadlines: [],
                    rateDetails: Self.rateDetails(fromGuestCount: guestCount),
                    passengers: []
                )
            }

            return nil
        }
    }

    private func externalUrl(schedulableType: String?, confirmationCode: String) -> String? {
        guard let schedulableType, !schedulableType.isEmpty else { return nil }
        guard let numericTripID = decodeTripNumericID(from: id) else { return nil }
        return "https://www.airbnb.de/trips/v1/\(numericTripID)/ro/\(schedulableType)/\(confirmationCode)"
    }

    private static func mapStatus(tripStatus: String?, reservationStatus: String?) -> BookingStatus {
        let haystack = ([tripStatus, reservationStatus].compactMap { $0 }).joined(separator: " ").lowercased()
        if haystack.contains("cancel") { return .cancelled }
        return .confirmed
    }

    private static func rateDetails(fromGuestCount count: Int?) -> BookingRateDetails? {
        guard let count, count > 0 else { return nil }
        return BookingRateDetails(guestCount: count)
    }
}

private func decodeTripNumericID(from relayID: String?) -> String? {
    guard let relayID else { return nil }
    guard let data = Data(base64Encoded: relayID) else { return nil }
    guard let decoded = String(data: data, encoding: .utf8) else { return nil }
    // Relay format is "Trip:<numericTripID>"
    if let range = decoded.range(of: "Trip:") {
        return String(decoded[range.upperBound...])
    }
    return nil
}

private extension AirbnbTripNode {
    struct TimeValue: Decodable {
        let listingTimeZone: String
        let dateTime: Date
    }
}

// MARK: - Response Model

private struct AirbnbTripListQueryEnvelope: Decodable {
    let data: AirbnbTripListQueryData
}

private struct AirbnbTripListQueryData: Decodable {
    let viewer: Viewer

    struct Viewer: Decodable {
        let trips: TripsConnection

        struct TripsConnection: Decodable {
            let edges: [TripEdge]

            struct TripEdge: Decodable {
                let node: AirbnbTripNode
            }
        }
    }
}

private struct AirbnbTripNode: Decodable {
    let id: String
    let displayName: String
    let status: String?
    let startTime: AirbnbTripTime
    let endTime: AirbnbTripTime
    let scheduledItems: ScheduledItemsConnection
    let travelerCapacity: TravelerCapacity?

    struct AirbnbTripTime: Decodable {
        let listingTimeZone: String
        let dateTime: Date
    }

    struct TravelerCapacity: Decodable {
        let numberOfAdults: Int?
    }

    struct ScheduledItemsConnection: Decodable {
        let edges: [ScheduledItemEdge]

        struct ScheduledItemEdge: Decodable {
            let node: ScheduledItemNode
        }
    }

    struct ScheduledItemNode: Decodable {
        let details: ScheduledItemDetails?
    }

    struct ScheduledItemDetails: Decodable {
        let __typename: String?
        let schedulableType: String?
        let stayReservation: StayReservation?
        let activityReservation: ActivityReservation?

        struct StayReservation: Decodable {
            let confirmationCode: String?
            let status: String?
        }

        struct ActivityReservation: Decodable {
            let confirmationCode: String?
            let status: String?
        }
    }
}

