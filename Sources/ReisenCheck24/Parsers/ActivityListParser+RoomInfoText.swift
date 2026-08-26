import Foundation

extension ActivityListParser {
    func parseRoomInfoText(_ trimmed: String) -> (count: Int?, category: String?) {
        // „1 Doppelzimmer mit Terrasse“ / „2x Suite“
        guard let regex = try? NSRegularExpression(
            pattern: #"^(\d+)\s*x?\s*(.+)$"#,
            options: [.caseInsensitive]
        ) else {
            return (nil, trimmed)
        }
        let ns = trimmed as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: full),
              match.numberOfRanges == 3 else {
            return (1, trimmed)
        }
        let count = Int(ns.substring(with: match.range(at: 1)))
        let category = ns.substring(with: match.range(at: 2))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (count, category.isEmpty ? nil : category)
    }
}
