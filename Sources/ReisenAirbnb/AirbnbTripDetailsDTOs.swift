import Foundation

struct AirbnbTripDetailsQueryEnvelope: Decodable {
    let data: AirbnbTripDetailsQueryData

    struct AirbnbTripDetailsQueryData: Decodable {
        let node: AirbnbTripDetailsNode
    }
}

struct AirbnbTripDetailsNode: Decodable {
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
    }

    struct GuestFacingLocation: Decodable {
        let oneLineAddress: String?
        let multiLineAddress: [String]?
    }

    struct TravelerCapacity: Decodable {
        let numberOfAdults: Int?
    }
}
