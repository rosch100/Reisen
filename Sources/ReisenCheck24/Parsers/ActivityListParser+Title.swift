import Foundation

extension ActivityListParser {
    func activityTitle(from activity: [String: Any]) -> String? {
        if let detail = activity["detail"] as? [String: Any],
           let line1 = detail["line1"] as? String,
           !line1.isEmpty {
            return line1
        }
        let psd = productSpecificData(from: activity)
        if let hotelName = psd["hotel_name"] as? String, !hotelName.isEmpty {
            return hotelName
        }
        return nil
    }
}
