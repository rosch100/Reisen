import Foundation

public enum AuthPageURLMarkerScan {
    public static func containsAnyMarker(_ haystack: String, _ markers: [String]) -> Bool {
        markers.contains { containsMarker(haystack, $0) }
    }

    public static func containsMarker(_ haystack: String, _ marker: String) -> Bool {
        var searchStart = haystack.startIndex
        while searchStart < haystack.endIndex,
              let range = haystack.range(of: marker, range: searchStart..<haystack.endIndex) {
            if marker == "account",
               AuthPageURLAccountMarker.shouldSkipPlural(haystack: haystack, range: range) {
                searchStart = range.upperBound
                continue
            }
            return true
        }
        return false
    }
}
