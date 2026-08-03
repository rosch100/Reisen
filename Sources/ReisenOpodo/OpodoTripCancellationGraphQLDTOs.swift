import Foundation

// MARK: - DTOs (getTripByToken Storno)

struct OpodoTripCancellationEnvelope: Decodable {
    let data: OpodoTripCancellationDataContainer?
}

struct OpodoTripCancellationDataContainer: Decodable {
    let getTrip: OpodoTripCancellationTripContainer?
}

struct OpodoTripCancellationTripContainer: Decodable {
    let trip: OpodoCancellationTripDTO?
}

struct OpodoCancellationTripDTO: Decodable {
    let id: String?
    let bookingStatus: String?
    let bookingProductStatus: String?
    let itinerary: OpodoCancellationItineraryDTO?
    let accommodationBooking: OpodoCancellationAccommodationDTO?
    let accommodationProductBooking: OpodoCancellationAccommodationProductBookingDTO?
}

struct OpodoCancellationAccommodationProductBookingDTO: Decodable {
    let cancellationPolicies: OpodoCancellationPoliciesDTO?
}

struct OpodoCancellationItineraryDTO: Decodable {
    let freeCancellation: String?
    let freeCancellationLimit: OpodoCancellationFreeCancellationLimitDTO?
}

struct OpodoCancellationFreeCancellationLimitDTO: Decodable {
    let limitTime: Int64?
    let hoursApart: Int64?
}

struct OpodoCancellationAccommodationDTO: Decodable {
    let bookingStatus: String?
    let cancellationDate: String?
    let roomsGroupCancelPolicy: String?
    let bookingCancelPolicy: String?
    let accommodationCancelPolicy: String?
    let cancellationInformation: OpodoCancellationInformationDTO?
    let cancellationPolicies: OpodoCancellationPoliciesDTO?
}

struct OpodoCancellationInformationDTO: Decodable {
    let cancellableStatus: String?
    let cancellationOptions: [OpodoCancellationOptionDTO]?
}

struct OpodoCancellationPoliciesDTO: Decodable {
    let cancellableStatus: String?
    let cancellationOptions: [OpodoCancellationOptionDTO]?
}

struct OpodoCancellationOptionDTO: Decodable {
    let from: String?
    let until: String?
    let refundAmount: OpodoCancellationMoneyDTO?
    let refundPercentage: Int?
}

struct OpodoCancellationMoneyDTO: Decodable {
    let amount: Double
    let currency: String
}
