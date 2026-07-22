import Foundation
import ReisenDomain

/// Parses structured flight passengers + luggage for Check24 bookings.
///
/// Data sources:
/// - `guestNames` inside the booking detail HTML (passenger names + count)
/// - `api/status/<filekey>:<surname>` JSON response (luggage per passenger/direction)
public struct Check24FlightPassengersAndLuggageParser: Sendable {
    public init() {}

    /// Extracts passenger name strings from the booking detail HTML.
    /// Example value in HTML: "Roland Schramme, Danila Liebe"
    public func guestNames(from html: String) -> [String] {
        // Pattern mirrors BookingDetailsParser's `guestNames` heuristic, but returns the raw names.
        // Example snippet:
        // <div class="... guestNames ...">Danila Liebe, Julian Liebe</div>
        let normalized = html
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")

        let pattern = #"guestNames[^>]*>\s*([^<]+?)\s*</div>"#
        guard let match = firstRegexMatch(pattern: pattern, in: normalized) else { return [] }

        return match
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Maps `includedLuggage` from the status endpoint into baggage allowances.
    ///
    /// Semantics:
    /// - We aggregate across all itinerary flights (outbound + inbound) to represent per-traveller totals.
    public func baggageAllowances(from statusJSON: String) throws -> [BaggageAllowance] {
        let payload = try decode(StatusEnvelope.self, from: statusJSON)
        let itinerary = payload.data.itinerary

        let flights = itinerary.flights
        let included: [IncludedLuggageItem] = {
            // Check24 gibt oft `includedLuggageEqual=true` für Hin-/Rückflug an.
            // Dann ist die „Luggage“-Anzeige im UI typischerweise pro Strecke identisch
            // und sollte nicht doppelt gezählt werden.
            if itinerary.includedLuggageEqual == true, let first = flights.first {
                return first.includedLuggage
            }
            return flights.flatMap(\.includedLuggage)
        }()

        var piecesByType: [BaggageType: Int] = [:]
        var weightKgByType: [BaggageType: Double] = [:]

        for item in included {
            let mappedType = baggageType(from: item.type)
            let pieceCount = item.pieces
            piecesByType[mappedType, default: 0] += pieceCount

            if let weight = item.weightKg, weight > 0 {
                // Keep the maximum observed per-piece weight for that type.
                weightKgByType[mappedType] = max(weightKgByType[mappedType] ?? 0, weight)
            }
        }

        return piecesByType.keys.compactMap { type in
            let pieces = piecesByType[type]
            guard let pieces, pieces > 0 else { return nil }
            let weightKg = weightKgByType[type]
            return BaggageAllowance(
                type: type,
                pieceCount: pieces > 0 ? pieces : nil,
                weightKg: weightKg != nil && (weightKg ?? 0) > 0 ? weightKg : nil
            )
        }
        // Stabilize output ordering for tests and deterministic persistence:
        .sorted { $0.type.rawValue < $1.type.rawValue }
    }

    /// Builds `BookingPassenger` objects by attaching the same baggage allowances to each passenger.
    public func buildPassengers(
        guestNames: [String],
        baggageAllowances: [BaggageAllowance],
        travellerType: TravellerType = .adult
    ) -> [BookingPassenger] {
        guard !guestNames.isEmpty else { return [] }

        return guestNames.enumerated().map { idx, fullName in
            let parts = fullName
                .split(separator: " ")
                .map(String.init)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            let familyName = parts.last
            let givenName = parts.dropLast().joined(separator: " ").nilIfEmpty

            return BookingPassenger(
                passengerNumber: idx + 1,
                travellerType: travellerType,
                title: nil,
                givenName: givenName,
                familyName: familyName,
                secondFamilyName: nil,
                birthDate: nil,
                // Create fresh baggage allowance IDs per passenger.
                baggageAllowances: baggageAllowances.map { existing in
                    BaggageAllowance(
                        type: existing.type,
                        pieceCount: existing.pieceCount,
                        weightKg: existing.weightKg,
                        sectionID: existing.sectionID,
                        airlineCode: existing.airlineCode,
                        fromLabel: existing.fromLabel,
                        toLabel: existing.toLabel
                    )
                }
            )
        }
    }

    private func baggageType(from check24Type: String) -> BaggageType {
        let normalized = check24Type.lowercased()
        if normalized.contains("checked") && normalized.contains("bag") {
            return .checkedBag
        }
        if normalized.contains("carry-on-small-bag") {
            return .personalItem
        }
        if normalized.contains("carry-on-bag") {
            return .cabinBag
        }
        // Fail-soft: unknown types should still be preserved as "unknown".
        return .unknown
    }

    private func firstRegexMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: fullRange),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        guard let data = json.data(using: .utf8) else {
            throw Check24FlightPassengersAndLuggageParserDecodeError.invalidUtf8
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw Check24FlightPassengersAndLuggageParserDecodeError.decodeFailed("\(error)")
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct StatusEnvelope: Decodable {
    let httpstatuscode: Int?
    let success: Bool?
    let data: StatusData

    struct StatusData: Decodable {
        let passengers: [StatusPassenger]?
        let itinerary: StatusItinerary
    }
}

private struct StatusPassenger: Decodable {
    let firstname: String?
    let surname: String?
    let type: String?
}

private struct StatusItinerary: Decodable {
    let flights: [StatusFlight]
    let includedLuggageEqual: Bool?
}

private struct StatusFlight: Decodable {
    let segments: [StatusSegment]?
    let includedLuggage: [IncludedLuggageItem]
}

private struct StatusSegment: Decodable {
    let id: Int?
}

private struct IncludedLuggageItem: Decodable {
    let type: String
    let pieces: Int
    let weightKg: Double?
}

private enum Check24FlightPassengersAndLuggageParserDecodeError: LocalizedError {
    case invalidUtf8
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidUtf8:
            return "JSON konnte nicht in UTF-8 konvertiert werden."
        case .decodeFailed(let message):
            return "JSON konnte nicht decodiert werden: \(message)"
        }
    }
}

