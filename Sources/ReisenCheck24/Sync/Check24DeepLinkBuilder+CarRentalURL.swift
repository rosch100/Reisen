import Foundation
import ReisenDomain

extension Check24DeepLinkBuilder {
    /// Gap → Mietwagen-Suche. Live 2026-08-28: `/ul/jumpin` mit Name-Params füllt
    /// Abhol-/Rückgabeort vor (ohne Destination-IDs). Keine reinen IATA-Codes.
    func makeCarRentalSearchURL(for gap: GapContext) throws -> URL {
        let pickup = firstCarRentalPlace(gap.fromLocationTo, gap.fromLocationFrom)
        let dropoff = firstCarRentalPlace(gap.toLocationFrom, gap.toLocationTo)
        guard let start = pickup ?? dropoff else {
            throw DeepLinkIssue.missingDestinationHint
        }
        let end = dropoff ?? start
        guard let url = Check24CarRentalJumpin.searchURL(pickup: start, dropoff: end) else {
            throw DeepLinkIssue.missingDestinationHint
        }
        return url
    }

    private func firstCarRentalPlace(_ values: String?...) -> String? {
        values.lazy.compactMap(carRentalPlaceName).first
    }

    /// Ortsname für Jumpin: Hotel-ID und reine IATA-Codes verwerfen.
    private func carRentalPlaceName(_ raw: String?) -> String? {
        guard var name = NonEmpty.string(raw) else { return nil }
        name = strippingNumericHotelDestinationID(from: name)
        name = strippingParentheticalIATA(from: name)
        guard let name = NonEmpty.string(name) else { return nil }
        if isBareIATACode(name) { return nil }
        return name
    }

    /// Hotel-Hints wie `Side-81907` → Ortsname ohne numerische Destination-ID.
    private func strippingNumericHotelDestinationID(from name: String) -> String {
        guard let dash = name.lastIndex(of: "-") else { return name }
        let suffix = name[name.index(after: dash)...]
        guard !suffix.isEmpty, suffix.allSatisfy(\.isNumber) else { return name }
        return String(name[..<dash])
    }

    /// `Frankfurt (FRA)` → `Frankfurt` (Flug-Hints mit IATA in Klammern).
    private func strippingParentheticalIATA(from name: String) -> String {
        let pattern = #"\s*\([A-Za-z]{3}\)\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return name }
        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        return regex.stringByReplacingMatches(in: name, range: range, withTemplate: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isBareIATACode(_ name: String) -> Bool {
        name.count == 3 && name.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
    }
}
