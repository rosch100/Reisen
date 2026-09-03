import Foundation
import ReisenDomain

extension ActivityListParser {
    func activityLocation(from activity: [String: Any], bookingType: BookingType) -> String? {
        let psd = productSpecificData(from: activity)
        if let city = jsonString(psd, "hotel_city_name") {
            return city
        }

        guard let line2 = catalogDetailLine2(from: activity) else { return nil }

        switch bookingType {
        case .hotel:
            // Check24 KB: line2 ist Ort („Jakarta, Indonesien“) oder Zimmertyp („Kapsel mit …“).
            return Check24CatalogDetailLine.looksLikeRoomCategory(line2) ? nil : line2
        case .carRental, .activity, .flight, .ferry, .train, .other:
            return line2
        }
    }

    func catalogDetailLine2(from activity: [String: Any]) -> String? {
        guard let detail = activity["detail"] as? [String: Any],
              let line2 = NonEmpty.string(detail["line2"] as? String),
              !line2.lowercased().contains("gebucht am") else {
            return nil
        }
        return line2
    }
}
