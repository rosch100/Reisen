import Foundation

extension ActivityListParser {
    func activityAddress(from activity: [String: Any]) -> String? {
        let psd = productSpecificData(from: activity)
        let streetPart = nonEmptyAddressPart(psd["hotel_street"] as? String)
        let cityPart = cityAddressPart(
            city: psd["hotel_city_name"] as? String,
            postalCode: psd["hotel_zipcode"] as? String
        )
        let countryPart = nonEmptyAddressPart(psd["hotel_country_name"] as? String)
        let parts = [streetPart, cityPart, countryPart].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }
}
