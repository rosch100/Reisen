import Foundation

extension ActivityListParser {
    func stripMobileHotelPrefix(_ urlString: String) -> String {
        urlString
            .replacingOccurrences(of: "https://m.hotel.check24.de/ul/", with: "https://hotel.check24.de/")
            .replacingOccurrences(of: "http://m.hotel.check24.de/ul/", with: "https://hotel.check24.de/")
    }
}
