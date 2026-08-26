import Foundation

public enum BaggagePassengerLines {
    public static func sharedLine(from allowances: [BaggageAllowance]) -> String {
        let parts = BaggageAllowanceFormatting.formattedParts(from: allowances)
        guard !parts.isEmpty else { return "" }
        return parts.joined(separator: "; ")
    }

    public static func perPassengerLines(passengers: [BookingPassenger]) -> String {
        let lines: [String] = passengers.compactMap { passenger in
            let parts = BaggageAllowanceFormatting.formattedParts(from: passenger.baggageAllowances)
            guard !parts.isEmpty else { return nil }
            return "Pax \(passenger.passengerNumber): \(parts.joined(separator: "; "))"
        }
        return lines.joined(separator: "\n")
    }
}
