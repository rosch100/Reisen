import Foundation
import ReisenDomain

extension ActivityListParser {
    func activityDetailURL(from activity: [String: Any], bookingType: BookingType) -> String? {
        if let linkObj = activity["link"] as? [String: Any],
           let link = linkObj["link"] as? String,
           !link.isEmpty {
            return normalizeBookingDetailURL(link, bookingType: bookingType)
        }
        if let url = travelInformationDesktopURL(from: activity) {
            return normalizeBookingDetailURL(url, bookingType: bookingType)
        }
        return bookingUUIDDetailURL(from: activity, bookingType: bookingType)
    }
}
