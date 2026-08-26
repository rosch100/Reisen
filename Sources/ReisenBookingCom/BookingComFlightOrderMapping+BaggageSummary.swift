import Foundation

extension BookingComFlightOrderParser {
    func baggageSummary(from order: FlightOrderEnvelope) -> String? {
        guard let segment = firstSegment(order) else { return nil }
        var parts: [String] = []

        if let checked = segment.travellerCheckedLuggage?.first?.luggageAllowance {
            parts.append(formatAllowance(checked, label: "Aufgabe"))
        }
        if let cabin = segment.travellerCabinLuggage?.first?.luggageAllowance {
            parts.append(formatAllowance(cabin, label: "Hand"))
        }

        if parts.isEmpty {
            parts.append(contentsOf: baggageSummaryFallbackParts(from: order))
        }

        let unique = parts.filter { !$0.isEmpty }
        return unique.isEmpty ? nil : unique.joined(separator: "; ")
    }
}
