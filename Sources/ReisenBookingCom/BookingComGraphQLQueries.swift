import Foundation

/// GraphQL-Query-Strings und zugehörige Trip-XP-Konstanten (HAR-shaped).
enum BookingComGraphQLQueries {
    static let graphqlURL = URL(string: "https://secure.booking.com/dml/graphql")!
    static let apolloClientName = "b-trips-frontend-trip-xp-mfe"

    /// Nur aktuelle/kommende Reisen (HAR SSR). PAST bläht den Katalog auf und ist für Sync irrelevant.
    static let tripListStageGroups: [[String]] = [
        ["CURRENT", "UPCOMING"],
    ]

    static let timelineSupportedConnectors: [String] = [
        "ACCOMMODATION_POB", "ADD_REVIEW", "APP_MANAGE_RESERVATION",
        "BASIC_TRIP", "CANCEL_BOOKING", "CONTACT_HELP_CENTER",
        "FLIGHT_CANCELLATION_INFO", "FLIGHT_DELAY_INFO", "FLIGHT_ONLINE_CHECK_IN",
        "FREE_CANCELLATION_REMINDER", "GET_DIRECTION", "HELP_CENTER",
        "MESSAGE_PROPERTY", "VIEW_RESERVATION", "MENU_ITEM_VIEW_RESERVATION",
        "MENU_ITEM_CANCEL_RESERVATION", "MENU_ITEM_VIEW_CANCEL_POLICY",
    ]

    static let getTripsQuery = """
    query GetTripsQuery($input: GetTripsInput!) {
      tripsQueries {
        getTrips(input: $input) {
          __typename
          ... on GetTripsList {
            trips {
              id
              title
              startDateTime
              endDateTime
              canceled
              numberOfReservations
              __typename
            }
            nextPageData {
              paginationToken
              __typename
            }
            __typename
          }
          ... on TripsListError {
            statusCode
            response
            __typename
          }
        }
        __typename
      }
    }
    """

    /// HAR-shaped: gemeinsame Reservation-Felder außerhalb der Inline-Fragments.
    static let singleTimelineQuery = """
    query SingleTimelineQuery($input: SingleTripTimelineInput!) {
      singleTripTimelineQueries {
        singleTripTimeline(input: $input) {
          ... on TripTimeline {
            trip {
              id
              title
              startDateTime
              endDateTime
              canceled
              __typename
            }
            timelineGroups {
              tripItems {
                __typename
                ... on ReservationTripItem {
                  reservation {
                    __typename
                    bookingUrl
                    startDateTime
                    endDateTime
                    verticalType
                    reservationStatus
                    price { amount currency __typename }
                    identifiers {
                      publicId
                      publicFacingIdentifier
                      ... on AccommodationReservationIdentifiers {
                        hotelReservationId
                        __typename
                      }
                      __typename
                    }
                    ... on AccommodationReservation {
                      reservationDetailsURL
                      numOfRooms
                      authKey
                      checkIn { start end __typename }
                      checkOut { start end __typename }
                      policy { name type message __typename }
                      propertyData {
                        ... on ReservationPropertyData {
                          name
                          location {
                            city
                            ... on AccommodationLocation {
                              address
                              __typename
                            }
                            __typename
                          }
                          __typename
                        }
                        __typename
                      }
                    }
                    ... on FlightReservation {
                      passengerCount
                      flightComponents {
                        parts {
                          flightNumber
                          startDateTime
                          endDateTime
                          startLocation {
                            iata
                            location { city __typename }
                            __typename
                          }
                          endLocation {
                            iata
                            location { city __typename }
                            __typename
                          }
                          marketingCarrier { code __typename }
                          __typename
                        }
                        __typename
                      }
                    }
                  }
                }
              }
              __typename
            }
            __typename
          }
        }
        __typename
      }
    }
    """
}
