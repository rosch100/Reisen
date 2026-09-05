import Foundation

// MARK: - Codable DTOs for Trip-XP GraphQL

struct GetTripsListPayload {
    let trips: [GetTrip]
    let nextPageData: GetTripsNextPage?
}

struct GetTripsEnvelope: Decodable {
    let data: GetTripsData?
    let errors: [GraphQLErrorMessage]?
}

struct GraphQLErrorMessage: Decodable {
    let message: String?
}

struct GetTripsData: Decodable {
    let tripsQueries: GetTripsQueries?
}

struct GetTripsQueries: Decodable {
    let getTrips: GetTripsResult?
}

struct GetTripsResult: Decodable {
    let typeName: String?
    let trips: [GetTrip]?
    let nextPageData: GetTripsNextPage?

    enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
        case trips
        case nextPageData
    }
}

struct GetTrip: Decodable {
    let id: String?
    let canceled: Bool?
}

struct GetTripsNextPage: Decodable {
    let paginationToken: String?
}

struct TimelineEnvelope: Decodable {
    let data: TimelineData?
    let errors: [GraphQLErrorMessage]?
}

struct TimelineData: Decodable {
    let singleTripTimelineQueries: SingleTripTimelineQueries?
}

struct SingleTripTimelineQueries: Decodable {
    let singleTripTimeline: SingleTripTimeline?
}

struct SingleTripTimeline: Decodable {
    let trip: GraphQLTrip?
    let timelineGroups: [TripItemGroup]?
}

struct GraphQLTrip: Decodable {
    let title: String?
    /// Trip-XP GraphQL `canceled` (US-Schreibweise); true → Katalog als storniert behandeln.
    let canceled: Bool?
}

struct TripItemGroup: Decodable {
    let tripItems: [TripItem]?
}

struct TripItem: Decodable {
    let reservation: GraphQLReservation?
}

struct GraphQLReservation: Decodable {
    let typeName: String?
    let verticalType: String?
    let bookingUrl: String?
    let reservationDetailsURL: String?
    let startDateTime: String?
    let endDateTime: String?
    let reservationStatus: String?
    let numOfRooms: Int?
    let passengerCount: Int?
    let price: GraphQLPrice?
    let propertyData: GraphQLPropertyData?
    let identifiers: GraphQLIdentifiers?
    let flightComponents: [GraphQLFlightComponent]?
    let checkIn: GraphQLCheckWindow?
    let checkOut: GraphQLCheckWindow?
    let policy: GraphQLPolicy?
    let ticketCount: Int?
    let bookingRef: String?
    let product: GraphQLReservationProduct?
    let pickUp: GraphQLTaxiStop?
    let dropOff: GraphQLTaxiStop?
    let pickUpLocation: GraphQLLocation?
    let dropOffLocation: GraphQLLocation?

    enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
        case verticalType
        case bookingUrl
        case reservationDetailsURL
        case startDateTime
        case endDateTime
        case reservationStatus
        case numOfRooms
        case passengerCount
        case price
        case propertyData
        case identifiers
        case flightComponents
        case checkIn
        case checkOut
        case policy
        case ticketCount
        case bookingRef
        case product
        case pickUp
        case dropOff
        case pickUpLocation
        case dropOffLocation
    }
}

struct GraphQLReservationProduct: Decodable {
    let name: String?
    let location: GraphQLLocation?
    let carClass: String?
    let supplier: String?
    let providerName: String?
    let vehicleTypeText: String?
}

struct GraphQLTaxiStop: Decodable {
    let location: GraphQLLocation?
}

struct GraphQLPrice: Decodable {
    let amount: Double
    let currency: String
}

struct GraphQLPropertyData: Decodable {
    let name: String?
    let location: GraphQLLocation?
}

struct GraphQLLocation: Decodable {
    let city: String?
    let address: String?
    let airportCode: String?
    let airportName: String?
}

struct GraphQLIdentifiers: Decodable {
    let hotelReservationId: String?
    let publicId: String?
    let publicFacingIdentifier: String?
}

struct GraphQLFlightComponent: Decodable {
    let parts: [GraphQLFlightPart]?
}

struct GraphQLFlightPart: Decodable {
    let startLocation: GraphQLAirport?
    let endLocation: GraphQLAirport?
    let marketingCarrier: GraphQLCarrier?
    let flightNumber: String?
}

struct GraphQLAirport: Decodable {
    let iata: String?
    let location: GraphQLLocation?
}

struct GraphQLCarrier: Decodable {
    let code: String?
}

struct GraphQLCheckWindow: Decodable {
    let start: String?
    let end: String?
}

struct GraphQLPolicy: Decodable {
    let name: String?
    let type: String?
    let message: String?
}
