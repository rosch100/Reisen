import Foundation

/// SSOT: Opodo Trip-Detail mit Stornofeldern.
/// HAR (`www.opodo.de` 2026-07-18 entry 797): Hotel-„Stornierungsrichtlinie“ kommt ausschließlich
/// aus `accommodationProductBooking.cancellationPolicies` (Fragment `HotelInformation`).
/// Die erweiterte Query mit `accommodationBooking.*` / `itinerary.*` liefert HTTP 400.
public enum OpodoGetTripByTokenQuery {
    /// HAR-stabile Minimalquery + Statusfelder (Storno erkennen, auch ohne Fristen).
    public static let query = """
    query getTripByToken($token: String!) {
      getTrip: getTripByToken(token: $token) {
        trip {
          bookingStatus
          bookingProductStatus
          accommodationBooking {
            bookingStatus
          }
          accommodationProductBooking {
            cancellationPolicies {
              cancellableStatus
              cancellationOptions {
                from
                until
                refundAmount {
                  amount
                  currency
                }
                refundPercentage
              }
            }
          }
        }
      }
    }
    """

    public static func requestBody(token: String) throws -> Data {
        try OpodoGraphQLRequest.body(
            query: query,
            operationName: "getTripByToken",
            variables: ["token": token]
        )
    }
}
