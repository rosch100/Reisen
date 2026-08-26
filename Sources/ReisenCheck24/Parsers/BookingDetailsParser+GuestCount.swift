import Foundation

extension BookingDetailsParser {
    func parseGuestCount(from html: String) -> Int? {
        // Beispiel: guestNames">Anna Example, Ben Sample</div>
        let pattern = #"guestNames[^>]*>\s*([^<]+?)\s*</div>"#
        guard let guestNames = firstRegexMatch(pattern: pattern, in: html) else { return nil }

        // Heuristik: Komma-getrennte Liste der Namens-Tokens.
        let parts = guestNames
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.count
    }
}
