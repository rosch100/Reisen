import Foundation

enum ExpediaTripsListParser {
    /// Extracts `egti-*` trip view IDs from `/trips` HTML (`?source=tripList` links preferred).
    static func tripViewIDs(fromHTML html: String) -> [String] {
        var ordered: [String] = []
        var seen = Set<String>()
        let patterns = [
            #"href="https://www\.expedia\.de/trips/(egti-[A-Za-z0-9-]+)\?source=tripList""#,
            #"href="https://www\.expedia\.de/trips/(egti-[A-Za-z0-9-]+)""#,
            #"/(trips)/(egti-[A-Za-z0-9-]+)"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
                guard let match else { return }
                let idRangeIndex = match.numberOfRanges > 2 ? 2 : 1
                guard let idRange = Range(match.range(at: idRangeIndex), in: html) else { return }
                let id = String(html[idRange])
                guard id.hasPrefix("egti-"), !seen.contains(id) else { return }
                seen.insert(id)
                ordered.append(id)
            }
            if !ordered.isEmpty { break }
        }
        return ordered
    }
}
