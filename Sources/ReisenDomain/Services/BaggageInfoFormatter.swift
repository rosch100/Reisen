import Foundation

/// Formats structured baggage info into a compact, UI/DB-friendly string.
///
/// Core goal:
/// - If all passengers have identical baggage allowances, we suppress redundancy:
///   `Aufgabe 1× 10KG; Hand 1× 5KG` (no `Pax n:` prefix).
/// - Otherwise we keep per-passenger lines, but normalize labels to German/Booking.com style.
public enum BaggageInfoFormatter {
    public static func baggageInfoRaw(passengers: [BookingPassenger]) -> String {
        guard !passengers.isEmpty else { return "" }

        let canonicalByPassenger = passengers.map { canonicalAllowances(from: $0.baggageAllowances) }
        let allIdentical = canonicalByPassenger.allSatisfy { $0 == canonicalByPassenger.first }

        // If all passengers are identical, we can render one aggregated line.
        if allIdentical {
            return aggregatedBaggageInfoRaw(from: passengers.first?.baggageAllowances ?? [])
        }

        // Otherwise render per passenger lines, normalized.
        let lines: [String] = passengers.compactMap { passenger in
            let parts = formattedParts(from: passenger.baggageAllowances)
            guard !parts.isEmpty else { return nil }
            return "Pax \(passenger.passengerNumber): \(parts.joined(separator: "; "))"
        }
        return lines.joined(separator: "\n")
    }

    private struct CanonicalAllowance: Equatable {
        let type: BaggageType
        let pieceCount: Int?
        let weightKgRounded1Decimal: Double?
    }

    private static func canonicalAllowances(from allowances: [BaggageAllowance]) -> [CanonicalAllowance] {
        let normalized = allowances.map { allowance in
            CanonicalAllowance(
                type: allowance.type,
                pieceCount: allowance.pieceCount,
                weightKgRounded1Decimal: allowance.weightKg.map { roundTo1Decimal($0) }
            )
        }

        return normalized
            .sorted {
                if $0.type.rawValue != $1.type.rawValue { return $0.type.rawValue < $1.type.rawValue }
                if $0.pieceCount != $1.pieceCount { return ($0.pieceCount ?? -1) < ($1.pieceCount ?? -1) }
                return ($0.weightKgRounded1Decimal ?? -1) < ($1.weightKgRounded1Decimal ?? -1)
            }
    }

    private static func aggregatedBaggageInfoRaw(from allowances: [BaggageAllowance]) -> String {
        let parts = formattedParts(from: allowances)
        guard !parts.isEmpty else { return "" }
        return parts.joined(separator: "; ")
    }

    private static func formattedParts(from allowances: [BaggageAllowance]) -> [String] {
        let sorted = allowances.sorted { $0.type.rawValue < $1.type.rawValue }
        return sorted.compactMap { allowancePart($0) }
    }

    private static func allowancePart(_ allowance: BaggageAllowance) -> String? {
        switch allowance.type {
        case .checkedBag:
            return buildPart(label: "Aufgabe", pieceCount: allowance.pieceCount, weightKg: allowance.weightKg)
        case .cabinBag:
            return buildPart(label: "Hand", pieceCount: allowance.pieceCount, weightKg: allowance.weightKg)
        case .personalItem:
            return buildPart(label: "Personal", pieceCount: allowance.pieceCount, weightKg: allowance.weightKg)
        case .unknown:
            return nil
        }
    }

    private static func buildPart(label: String, pieceCount: Int?, weightKg: Double?) -> String {
        var bits: [String] = [label]

        if let pieceCount {
            bits.append("\(pieceCount)×")
        }
        if let weightKg {
            let weightString = formatWeightKg(weightKg)
            bits.append("\(weightString)KG")
        }

        // If we only have the label (no piece/weight), still show it explicitly.
        return bits.joined(separator: " ")
    }

    private static func formatWeightKg(_ weightKg: Double) -> String {
        let rounded = roundTo1Decimal(weightKg)
        let oneDecimal = String(format: "%.1f", rounded)
        // Prefer `10KG` over `10.0KG` where possible.
        if oneDecimal.hasSuffix(".0") {
            return String(oneDecimal.dropLast(2))
        }
        return oneDecimal
    }

    private static func roundTo1Decimal(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}

