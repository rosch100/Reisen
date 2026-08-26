import Foundation

extension ActivityListParser {
    func bookingUUIDDetailURL(from activity: [String: Any]) -> String? {
        let psd = productSpecificData(from: activity)
        if let uuid = psd["booking_uuid"] as? String, !uuid.isEmpty {
            return "https://hotel.check24.de/kundenbereich/buchung/\(uuid)"
        }
        if let uuid = activity["booking_uuid"] as? String, !uuid.isEmpty {
            return "https://hotel.check24.de/kundenbereich/buchung/\(uuid)"
        }
        return nil
    }
}
