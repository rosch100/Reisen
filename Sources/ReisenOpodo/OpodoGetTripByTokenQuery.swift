import Foundation
import ReisenDomain

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
        let payload: [String: Any] = [
            "query": query,
            "operationName": "getTripByToken",
            "variables": ["token": token],
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    /// Token aus `…#tripdetails/td=<token>`.
    public static func tdToken(fromExternalURL urlString: String) -> String? {
        guard let marker = urlString.range(of: "#tripdetails/td=") else { return nil }
        let raw = String(urlString[marker.upperBound...])
        let token = raw.split(whereSeparator: { $0 == "/" || $0 == "?" || $0 == "&" || $0 == "#" }).first
        guard let token, !token.isEmpty else { return nil }
        return String(token)
    }
}
