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

enum AirbnbTripDetailsParser {
    static func parse(
        responseText: String,
        bookingType: BookingType,
        confirmationCode: String
    ) throws -> AirbnbTripDetails {
        let decoded = try JSONDecoder.airbnb.decode(
            AirbnbTripDetailsQueryEnvelope.self,
            from: Data(responseText.utf8)
        )
        let node = decoded.data.node
        guard let edge = node.scheduledItems.edges.first(where: { edge in
            switch bookingType {
            case .hotel:
                return edge.node.details?.stayReservation?.confirmationCode == confirmationCode
            default:
                return edge.node.details?.activityReservation?.confirmationCode == confirmationCode
            }
        }) else {
            throw AirbnbParsingError.confirmationCodeNotFound
        }

        guard let details = edge.node.details else {
            throw AirbnbParsingError.missingScheduledItems
        }

        let reservationDetails: ReservationDetails?
        let status: String?
        switch bookingType {
        case .hotel:
            guard let stay = details.stayReservation else { throw AirbnbParsingError.confirmationCodeNotFound }
            reservationDetails = ReservationDetails(stay: stay, supply: details.supply)
            status = stay.status
        default:
            guard let activity = details.activityReservation else { throw AirbnbParsingError.confirmationCodeNotFound }
            reservationDetails = ReservationDetails(activity: activity)
            status = activity.status
        }

        guard let reservation = reservationDetails else {
            throw AirbnbParsingError.confirmationCodeNotFound
        }

        return AirbnbTripDetails(
            listingTimeZone: node.startTime.listingTimeZone,
            tripStartAt: node.startTime.dateTime,
            tripEndAt: node.endTime.dateTime,
            displayName: node.displayName,
            schedulableType: details.schedulableType,
            confirmationCode: confirmationCode,
            guestAdults: reservation.guestAdults,
            oneLineAddress: edge.node.guestFacingLocation?.oneLineAddress,
            roomCount: reservation.roomCount,
            reservationStatus: status
        )
    }
}

enum AirbnbParsingError: Error {
    case missingScheduledItems
    case confirmationCodeNotFound
}

/// Normalizes stay vs experience details into one internal shape.
private struct ReservationDetails {
    let guestAdults: Int?
    let roomCount: Int?

    init(stay: AirbnbStayReservation, supply: AirbnbSupplyListing?) {
        guestAdults = stay.guestCountDetails?.numberOfAdults
        roomCount = supply?.roomsAndSpaces?.numberOfBedrooms
    }

    init(activity: AirbnbActivityReservation) {
        // Experiences don't map cleanly onto hotel room counts/guests in current model.
        guestAdults = nil
        roomCount = nil
    }
}

// MARK: - Response Model

private struct AirbnbTripDetailsQueryEnvelope: Decodable {
    let data: AirbnbTripDetailsQueryData

    struct AirbnbTripDetailsQueryData: Decodable {
        let node: Node
    }
}

private struct Node: Decodable {
    let displayName: String
    let startTime: TripTime
    let endTime: TripTime
    let scheduledItems: ScheduledItemsConnection
    let status: String?

    let travelerCapacity: TravelerCapacity?

    struct TripTime: Decodable {
        let listingTimeZone: String
        let dateTime: Date
    }

    struct ScheduledItemsConnection: Decodable {
        let edges: [ScheduledItemEdge]

        struct ScheduledItemEdge: Decodable {
            let node: ScheduledItemNode
        }
    }

    struct ScheduledItemNode: Decodable {
        let details: ScheduledItemDetails?
        let guestFacingLocation: GuestFacingLocation?
    }

    struct ScheduledItemDetails: Decodable {
        let schedulableType: String?
        let stayReservation: AirbnbStayReservation?
        let activityReservation: AirbnbActivityReservation?
        let supply: AirbnbSupplyListing?

        // Coding key mapping is handled by JSON decoder as field names match.
    }

    struct GuestFacingLocation: Decodable {
        let oneLineAddress: String?
        let multiLineAddress: [String]?
    }

    struct TravelerCapacity: Decodable {}
}

// MARK: - Stay/Activity submodels

private struct AirbnbStayReservation: Decodable {
    let confirmationCode: String?
    let status: String?
    let guestCountDetails: GuestCountDetails?
    let supplyListing: AirbnbSupplyListing?
}

private struct AirbnbActivityReservation: Decodable {
    let confirmationCode: String?
    let status: String?
}

private struct GuestCountDetails: Decodable {
    let numberOfAdults: Int?
}

private struct AirbnbSupplyListing: Decodable {
    let roomsAndSpaces: RoomsAndSpaces?
}

private struct RoomsAndSpaces: Decodable {
    let numberOfBedrooms: Int?
}

// MARK: - Decoder helpers

private extension JSONDecoder {
    static let airbnb: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

