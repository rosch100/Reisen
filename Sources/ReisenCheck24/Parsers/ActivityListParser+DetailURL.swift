import Foundation

extension ActivityListParser {
    func activityDetailURL(from activity: [String: Any]) -> String? {
        if let linkObj = activity["link"] as? [String: Any],
           let link = linkObj["link"] as? String,
           !link.isEmpty {
            return normalizeBookingDetailURL(link)
        }
        if let url = travelInformationDesktopURL(from: activity) {
            return normalizeBookingDetailURL(url)
        }
        return bookingUUIDDetailURL(from: activity)
    }
}
