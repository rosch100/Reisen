import Foundation

/// Formats structured baggage info into a compact, UI/DB-friendly string.
public enum BaggageInfoFormatter {
    public static func baggageInfoRaw(passengers: [BookingPassenger]) -> String {
        guard !passengers.isEmpty else { return "" }

        let canonicalByPassenger = passengers.map {
            BaggageCanonicalAllowances.canonical(from: $0.baggageAllowances)
        }
        let allIdentical = canonicalByPassenger.allSatisfy { $0 == canonicalByPassenger.first }

        if allIdentical {
            return BaggagePassengerLines.sharedLine(
                from: passengers.first?.baggageAllowances ?? []
            )
        }
        return BaggagePassengerLines.perPassengerLines(passengers: passengers)
    }
}
