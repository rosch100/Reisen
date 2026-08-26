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
}
