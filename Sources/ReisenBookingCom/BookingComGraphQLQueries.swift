import Foundation

/// GraphQL-Query-Strings und zugehörige Trip-XP-Konstanten (MFE 2026-08).
enum BookingComGraphQLQueries {
    static let graphqlURL = URL(string: "https://secure.booking.com/dml/graphql")!
    static let apolloClientName = "b-trips-frontend-trip-xp-mfe"

    /// Nur aktuelle/kommende Reisen (HAR SSR). PAST bläht den Katalog auf und ist für Sync irrelevant.
    static let tripListStageGroups: [[String]] = [
        ["CURRENT", "UPCOMING"],
    ]

    /// Live-`P`-Array der V1-`SingleTimelineQuery` (MFE 2026-08). UI-Flags, keine Buchungstypen.
    static let timelineSupportedExperiences: [String] = [
        "ACCOMMODATION_ARRIVAL",
        "ACCOMMODATION_INSTAY",
        "ACCOMMODATION_PRETRIPS",
        "BHOME_ARRIVAL",
        "POST_TRIP",
        "TAXI_ARRIVAL",
    ]

    /// Live-`R`-Array der V1-Timeline (MFE 2026-08). Connectors sind UI-Flags.
    static let timelineSupportedConnectors: [String] = [
        "ACCOMMODATION_POB", "ADD_REVIEW", "APP_MANAGE_RESERVATION",
        "B4B_EXPENSE_MANAGEMENT_FEATURE_INTEREST", "B4B_PROMOTION", "BASIC_TRIP",
        "CANCEL_BOOKING", "CONTACT_HELP_CENTER", "DEALS_UNLOCKED", "EARLY_CHECK_IN",
        "EMERGENCY_MESSAGE_CONNECTOR", "FLIGHT_CANCELLATION_INFO", "FLIGHT_DELAY_INFO",
        "FLIGHT_ONLINE_CHECK_IN", "FLIGHT_SCHEDULE_CHANGES_INFO", "FREE_CANCELLATION_REMINDER",
        "GET_DIRECTION", "GET_TO_THE_PROPERTY", "GUEST_DATE_CHANGE", "HELP_CENTER",
        "INVALID_PAYMENT", "KEY_COLLECTION_INFO", "KNOW_BEFORE_YOU_GO", "LATE_CHECK_IN_SURVEY",
        "LATE_CHECK_IN", "MENU_ITEM_ADD_REVIEW", "MENU_ITEM_CANCEL_RESERVATION",
        "MENU_ITEM_GET_DIRECTION", "MENU_ITEM_HC_LINK", "MENU_ITEM_HIDE_RESERVATION",
        "MENU_ITEM_INVALID_PAYMENT", "MENU_ITEM_MANAGE_RESERVATION",
        "MENU_ITEM_MODIFY_DATE_RESERVATION_APPROVAL", "MENU_ITEM_MODIFY_DATE_RESERVATION",
        "MENU_ITEM_MSG_TO_RESERVATION", "MENU_ITEM_RECOVER_RESERVATION",
        "MENU_ITEM_SHARE_RESERVATION", "MENU_ITEM_USER_CHANGE_DATE",
        "MENU_ITEM_USER_REQUEST_DATE_CHANGE", "MENU_ITEM_VIEW_CANCEL_POLICY",
        "MENU_ITEM_VIEW_RESERVATION", "MESSAGE_PROPERTY", "PARKING_INFORMATION",
        "PARTNER_DATE_CHANGE", "PAY_NOW", "PROACTIVE_ALERTING", "REFUND_STATUS",
        "REQUEST_INVOICE", "REQUEST_TO_BOOK_FINISH_BOOKING", "SELF_SERVICE_STATUS",
        "SURVEY", "TAXI_COMPANION", "UNDO_ACCOMMODATION_CANCELLATION", "UPGRADE_ROOM",
        "VIEW_PRICE_DROP", "VIEW_RESERVATION", "PAYMENT_CLARITY",
        "AIRPORT_TRANSPORTATION_RECOMMENDATION", "CROSS_BORDER_POLICY", "WHAT_TO_PACK",
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

    /// V1 `singleTripTimelineQueries` (MFE 2026-08, weiterhin live). Fragmente inkl. Taxi/Attraction/Car.
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
                    ... on AttractionReservation {
                      ticketCount
                      product {
                        name
                        location { city __typename }
                        __typename
                      }
                    }
                    ... on CarReservation {
                      pickUpLocation { city __typename }
                      dropOffLocation { city __typename }
                      product {
                        carClass
                        name
                        supplier
                        __typename
                      }
                    }
                    ... on PrebookTaxiReservation {
                      bookingRef
                      pickUp {
                        location { city airportCode airportName __typename }
                        __typename
                      }
                      dropOff {
                        location { city __typename }
                        __typename
                      }
                      product {
                        providerName
                        vehicleTypeText
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
