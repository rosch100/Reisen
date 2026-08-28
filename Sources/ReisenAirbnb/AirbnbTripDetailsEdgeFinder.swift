import Foundation
import ReisenDomain

enum AirbnbTripDetailsEdgeFinder {
    static func find(
        in edges: [AirbnbTripDetailsNode.ScheduledItemsConnection.ScheduledItemEdge],
        bookingType: BookingType,
        confirmationCode: String
    ) throws -> AirbnbTripDetailsNode.ScheduledItemsConnection.ScheduledItemEdge {
        guard let edge = edges.first(where: { edge in
            matches(edge: edge, bookingType: bookingType, confirmationCode: confirmationCode)
        }) else {
            throw AirbnbParsingError.confirmationCodeNotFound
        }
        return edge
    }

    static func matches(
        edge: AirbnbTripDetailsNode.ScheduledItemsConnection.ScheduledItemEdge,
        bookingType: BookingType,
        confirmationCode: String
    ) -> Bool {
        switch bookingType {
        case .hotel:
            return edge.node.details?.stayReservation?.confirmationCode == confirmationCode
        case .activity, .carRental, .flight, .ferry, .train, .other:
            return edge.node.details?.activityReservation?.confirmationCode == confirmationCode
        }
    }
}
