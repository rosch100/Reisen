import Foundation
import ReisenDomain

enum TravelokaStatusMapper {
    /// Rohstatus aus Tags und `userTripStatus` — Domain parst via `BookingStatus.parse`.
    static func statusRaw(from entry: [String: Any]) -> String? {
        let tags = entry["itineraryTags"] as? [[String: Any]] ?? []
        let tagTexts = tags.compactMap { TravelokaJSON.string($0["text"]) }
        let tripStatus = TravelokaJSON.string(
            (entry["paymentInfo"] as? [String: Any])?["userTripStatus"]
        )
        return BookingStatus.joinedRaw(tagTexts.map { Optional($0) } + [tripStatus])
    }
}
