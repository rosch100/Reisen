import Foundation
import ReisenDomain

/// Normalizes stay vs experience details into one internal shape.
struct AirbnbTripDetailsReservation {
    let guestAdults: Int?
    let roomCount: Int?
    let status: String?

    static func extract(
        from edge: AirbnbTripDetailsNode.ScheduledItemsConnection.ScheduledItemEdge,
        bookingType: BookingType
    ) throws -> AirbnbTripDetailsReservation {
        guard let details = edge.node.details else {
            throw AirbnbParsingError.missingScheduledItems
        }
        switch bookingType {
        case .hotel:
            guard let stay = details.stayReservation else {
                throw AirbnbParsingError.confirmationCodeNotFound
            }
            return AirbnbTripDetailsReservation(
                guestAdults: stay.guestCountDetails?.numberOfAdults,
                roomCount: details.supply?.roomsAndSpaces?.numberOfBedrooms,
                status: stay.status
            )
        case .activity:
            guard let activity = details.activityReservation else {
                throw AirbnbParsingError.confirmationCodeNotFound
            }
            return AirbnbTripDetailsReservation(
                guestAdults: activity.guestCountDetails?.numberOfAdults,
                roomCount: nil,
                status: activity.status
            )
        case .flight, .ferry, .other:
            guard let activity = details.activityReservation else {
                throw AirbnbParsingError.confirmationCodeNotFound
            }
            // Legacy Experiences may still arrive as `.other` until re-sync.
            return AirbnbTripDetailsReservation(
                guestAdults: activity.guestCountDetails?.numberOfAdults,
                roomCount: nil,
                status: activity.status
            )
        }
    }
}
