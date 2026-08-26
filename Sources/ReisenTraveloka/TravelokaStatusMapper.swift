import Foundation
import ReisenDomain

enum TravelokaStatusMapper {
    static func status(from entry: [String: Any]) -> BookingStatus {
        let tags = entry["itineraryTags"] as? [[String: Any]] ?? []
        let tagTexts = tags.compactMap { TravelokaJSON.string($0["text"])?.lowercased() }
        if tagTexts.contains(where: isCancelledStatusTag) {
            return .cancelled
        }
        if tagTexts.contains(where: isConfirmedStatusTag) {
            return .confirmed
        }

        let payment = entry["paymentInfo"] as? [String: Any]
        let tripStatus = TravelokaJSON.string(payment?["userTripStatus"])?.uppercased()
        if let tripStatus {
            if isCancelledTripStatus(tripStatus) {
                return .cancelled
            }
            if tripStatus == "ETICKET_PUBLISHED" || tripStatus == "ISSUED" {
                return .confirmed
            }
        }
        return .unknown
    }

    /// Explizite Storno-/Erstattet-Status — nicht „Refundable“ / „Non-cancellable“.
    static func isCancelledStatusTag(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.contains("refundable") { return false }
        if t.contains("non-cancel") || t.contains("noncancel") { return false }
        if t.contains("cancel") { return true }
        if t.contains("refunded") { return true }
        return false
    }

    static func isConfirmedStatusTag(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t.contains("voucher issued") || t.contains("e-ticket issued")
    }

    static func isCancelledTripStatus(_ tripStatus: String) -> Bool {
        cancelledTripStatuses.contains(tripStatus)
    }

    private static let cancelledTripStatuses: Set<String> = [
        "REFUNDED",
        "CANCELLED",
        "CANCELLATION_IN_PROGRESS",
        "CANCELLATION_SUCCESS",
        "CANCELLATION_COMPLETED",
    ]
}
