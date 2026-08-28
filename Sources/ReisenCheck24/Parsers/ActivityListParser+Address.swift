import Foundation
import ReisenDomain

extension ActivityListParser {
    func activityAddress(from activity: [String: Any]) -> String? {
        let psd = productSpecificData(from: activity)
        return PostalAddress.lines(
            street: jsonString(psd, "hotel_street"),
            postalCode: jsonString(psd, "hotel_zipcode"),
            city: jsonString(psd, "hotel_city_name"),
            country: jsonString(psd, "hotel_country_name")
        )
    }
}
