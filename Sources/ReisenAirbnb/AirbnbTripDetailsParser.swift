import Foundation
import ReisenDomain

/// Parsed subset of Airbnb `TripDetailsQuery`.
struct AirbnbTripDetails {
    let listingTimeZone: String
    let tripStartAt: Date
    let tripEndAt: Date
    let displayName: String
    let schedulableType: String?
    let confirmationCode: String?
    let guestAdults: Int?
    let oneLineAddress: String?
    let roomCount: Int?
    let reservationStatus: String?
}

enum AirbnbParsingError: Error {
    case missingScheduledItems
    case confirmationCodeNotFound
}

enum AirbnbTripDetailsParser {
    static func parse(
        responseText: String,
        bookingType: BookingType,
        confirmationCode: String
    ) throws -> AirbnbTripDetails {
        let decoded = try AirbnbJSONDecoder.shared.decode(
            AirbnbTripDetailsQueryEnvelope.self,
            from: Data(responseText.utf8)
        )
        let node = decoded.data.node
        let edge = try AirbnbTripDetailsEdgeFinder.find(
            in: node.scheduledItems.edges,
            bookingType: bookingType,
            confirmationCode: confirmationCode
        )
        let reservation = try AirbnbTripDetailsReservation.extract(
            from: edge,
            bookingType: bookingType
        )
        return AirbnbTripDetails(
            listingTimeZone: node.startTime.listingTimeZone,
            tripStartAt: node.startTime.dateTime,
            tripEndAt: node.endTime.dateTime,
            displayName: node.displayName,
            schedulableType: edge.node.details?.schedulableType,
            confirmationCode: confirmationCode,
            guestAdults: reservation.guestAdults ?? node.travelerCapacity?.numberOfAdults,
            oneLineAddress: NonEmpty.first(
                edge.node.guestFacingLocation?.oneLineAddress,
                joinedMultiLineAddress(edge.node.guestFacingLocation?.multiLineAddress)
            ),
            roomCount: reservation.roomCount,
            reservationStatus: reservation.status
        )
    }

    private static func joinedMultiLineAddress(_ lines: [String]?) -> String? {
        guard let lines else { return nil }
        let parts = lines.compactMap { NonEmpty.string($0) }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }
}
