import Foundation

extension ActivityListParser {
    func activityLocation(from activity: [String: Any]) -> String? {
        if let detail = activity["detail"] as? [String: Any],
           let line2 = detail["line2"] as? String,
           !line2.isEmpty,
           !line2.lowercased().contains("gebucht am") {
            return line2
        }
        let psd = productSpecificData(from: activity)
        return psd["hotel_city_name"] as? String
    }
}
