import Foundation

extension HotelBasketParser {
    static func formatGuestSummary(knownNames: [String], placeholderCount: Int) -> String? {
        if knownNames.isEmpty {
            return nil
        }
        if placeholderCount > 0 {
            // Nur ein bekannter Name nötig für den gewünschten Kanon.
            if knownNames.count == 1 {
                return "\(knownNames[0]) und \(placeholderCount) weitere Gäste"
            }
            return "\(knownNames.joined(separator: ", ")) und \(placeholderCount) weitere Gäste"
        }
        return knownNames.joined(separator: ", ")
    }
}
