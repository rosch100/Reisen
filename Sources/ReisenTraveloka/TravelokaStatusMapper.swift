import Foundation
import ReisenDomain

enum TravelokaStatusMapper {
    /// Rohstatus aus Tags, `itineraryBookingStatus` und `userTripStatus`
    /// (hotel/car/experience/flight u. a.) — Domain parst via `BookingStatus.parse`
    /// (Storno-Token vor Confirmed). `latestPaymentStatus` bewusst nicht:
    /// Live liefert FAILED auch bei aktiven SUCCESS-Buchungen.
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
            tagTexts.map { Optional($0) } + [bookingStatus, tripStatus]
        )
    }
}
