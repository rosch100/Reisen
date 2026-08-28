import Foundation

/// SSOT for Opodo `getTrips` request body (session-bound catalog).
public enum OpodoGetTripsQuery {
    /// Katalogfelder aus HAR/Live `getTrips` (nur Flug/Hotel). Kein `insuranceBookings`, keine Vehicle-/Transfer-Offers.
    public static let query = """
    query getTrips($filter: TripListFilter!, $maxNumBookingsByPage: Int!, $offsetPage: Int!) {
      getTrips(
        filter: $filter
        pagination: {
          maxNumBookingsByPage: $maxNumBookingsByPage
          offsetPage: $offsetPage
        }
      ) {
        trips {
          trip {
            id
            bookingStatus
            bookingProductStatus
            tdToken
            price { amount currency }
            travellers { travellerType }
            itinerary {
              transportTypes
              departureDate
              arrivalDate
              origin { cityName iata }
              destination { cityName iata }
              legs {
                sections {
                  pnr
                  flightCode
                  carrier { name }
                  departure { iata name }
                  arrival { iata name }
                }
              }
            }
            accommodationBooking {
              id
              city
              bookingStatus
              accommodationName
              address
              postalCode
              countryCode
              checkInDate
              checkOutDate
              checkIn
              checkOut
              boardType
              numberOfRooms
              numberOfAdults
              numberOfChildren
              bookingRooms { roomDescription }
            }
          }
        }
      }
    }
    """

    public static func requestBody(
        filter: String,
        maxNumBookingsByPage: Int,
        offsetPage: Int
    ) throws -> Data {
        try OpodoGraphQLRequest.body(
            query: query,
            operationName: "getTrips",
            variables: [
                "filter": filter,
                "maxNumBookingsByPage": maxNumBookingsByPage,
                "offsetPage": offsetPage,
            ]
        )
    }
}
