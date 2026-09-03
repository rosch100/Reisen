import Foundation
import ReisenDomain

enum TravelokaStatusMapper {
    /// Rohstatus aus Tags, `itineraryBookingStatus`, `userTripStatus` und
    /// product-detail `cancelled` (hotel/car/experience/flight u. a.) —
    /// Domain parst via `BookingStatus.parse` (Storno-Token vor Confirmed).
    /// `latestPaymentStatus` bewusst nicht: Live liefert FAILED auch bei
    /// aktiven SUCCESS-Buchungen. `isActiveBooking` bewusst nicht: aktive
    /// Experience-Fixtures setzen es ebenfalls auf false.
    static func statusRaw(from entry: [String: Any]) -> String? {
        let tags = entry["itineraryTags"] as? [[String: Any]] ?? []
        let tagTexts = tags.compactMap { TravelokaJSON.string($0["text"]) }
        let bookingStatus = TravelokaJSON.string(
            TravelokaJSON.commonSummary(from: entry)["itineraryBookingStatus"]
        )
        let tripStatus = TravelokaJSON.string(
            (entry["paymentInfo"] as? [String: Any])?["userTripStatus"]
        )
        return BookingStatus.joinedRaw(
            tagTexts.map { Optional($0) }
                + [bookingStatus, tripStatus, productDetailCancelledToken(from: entry)]
        )
    }

    /// Live Vehicle Rental: Catalog/Single behalten SUCCESS + Voucher issued,
    /// Storno steht in `cardDetailInfo.*.cancelled` (+ nested withoutDriver).
    private static func productDetailCancelledToken(from entry: [String: Any]) -> String? {
        guard productDetailIsCancelled(from: entry) else { return nil }
        return "CANCELLED"
    }

    private static func productDetailIsCancelled(from entry: [String: Any]) -> Bool {
        let detail = TravelokaJSON.cardDetail(from: entry)
        let roots = [
            TravelokaJSON.dictionary(detail["vehicleRentalDetailInfo"]),
            TravelokaJSON.dictionary(detail["experienceDetail"]),
            TravelokaJSON.dictionary(detail["hotelDetail"]),
            TravelokaJSON.dictionary(detail["flightDetail"]),
        ]
        for root in roots where isCancelledFlag(in: root) {
            return true
        }
        let vehicle = TravelokaJSON.dictionary(detail["vehicleRentalDetailInfo"])
        return isCancelledFlag(in: TravelokaJSON.dictionary(vehicle["withoutDriverDetailInfo"]))
    }

    private static func isCancelledFlag(in detail: [String: Any]) -> Bool {
        TravelokaJSON.bool(detail["cancelled"]) == true
    }
}
