import Foundation

extension BookingComFlightOrderParser {
    func baggageSummaryFallbackParts(from order: FlightOrderEnvelope) -> [String] {
        guard let luggage = order.luggageBySegment?.first?.first?.luggageAllowance else {
            return []
        }
        return luggage.map { item in
            formatAllowance(item, label: baggageFallbackLabel(for: item.luggageType))
        }
    }

    func baggageFallbackLabel(for luggageType: String?) -> String {
        switch luggageType?.uppercased() {
        case "CHECKED_IN":
            return "Aufgabe"
        case "HAND":
            return "Hand"
        case "PERSONAL_ITEM":
            return "Personal"
        default:
            return luggageType ?? "Gepäck"
        }
    }
}
