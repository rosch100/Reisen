import Foundation

// MARK: - Codable DTOs (getTrips catalog)

struct OpodoTripsEnvelope: Decodable {
    let data: OpodoTripsDataContainer?
}

struct OpodoTripsDataContainer: Decodable {
    let getTrips: OpodoTripsContainer?
}

struct OpodoTripsContainer: Decodable {
    let trips: [OpodoTripWrapper]?
}

struct OpodoTripWrapper: Decodable {
    let trip: OpodoGraphQLTrip?
}

struct OpodoGraphQLTrip: Decodable {
    let id: String?
    let bookingStatus: String?
    let bookingProductStatus: String?
    let tdToken: String?
    let price: OpodoGraphQLMoney?
    let travellers: [OpodoGraphQLTraveller]?
    let itinerary: OpodoGraphQLItinerary?
    let accommodationBooking: OpodoGraphQLAccommodation?
}

struct OpodoGraphQLMoney: Decodable {
    let amount: Double
    let currency: String
}

struct OpodoGraphQLTraveller: Decodable {
    let travellerType: String?
}

struct OpodoGraphQLItinerary: Decodable {
    let departureDate: Int64?
    let arrivalDate: Int64?
    let origin: OpodoGraphQLPlace?
    let destination: OpodoGraphQLPlace?
    let legs: [OpodoGraphQLLeg]?
}

struct OpodoGraphQLPlace: Decodable {
    let cityName: String?
    let iata: String?
}

struct OpodoGraphQLLeg: Decodable {
    let sections: [OpodoGraphQLSection]?
}

struct OpodoGraphQLSection: Decodable {
    let pnr: String?
    let flightCode: String?
    let carrier: OpodoGraphQLCarrier?
    let departure: OpodoGraphQLAirport?
    let arrival: OpodoGraphQLAirport?
}

struct OpodoGraphQLCarrier: Decodable {
    let name: String?
}

struct OpodoGraphQLAirport: Decodable {
    let iata: String?
    let name: String?
}

struct OpodoGraphQLAccommodation: Decodable {
    let id: String?
    let city: String?
    let bookingStatus: String?
    let accommodationName: String?
    let address: String?
    let postalCode: String?
    let countryCode: String?
    let checkInDate: Int64?
    let checkOutDate: Int64?
    let checkIn: String?
    let checkOut: String?
    let boardType: String?
    let numberOfRooms: Int?
    let numberOfAdults: Int?
    let numberOfChildren: Int?
    let bookingRooms: [OpodoGraphQLBookingRoom]?
}

struct OpodoGraphQLBookingRoom: Decodable {
    let roomDescription: String?
}
