import Foundation
import ReisenDomain

extension BookingComParsing {
    static func dedupeByExternalURL(_ bookings: [ProviderBookingDraft]) -> [ProviderBookingDraft] {
        ProviderCatalog(bookings: bookings).dedupedByExternalURL().bookings
    }

    /// Trip-IDs from My Trips SSR/HTML (`trip_id=`). HAR: present even when empty-state marketing copy is in the DOM.
    static func tripIDsFromMyTripsHTML(_ html: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"trip_id=(\d{6,})"#,
            options: [.caseInsensitive]
        ) else { return [] }
        let ns = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: ns.length))
        var ordered: [String] = []
        var seen = Set<String>()
        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let id = ns.substring(with: match.range(at: 1))
            guard !seen.contains(id) else { continue }
            seen.insert(id)
            ordered.append(id)
        }
        return ordered
    }
}
