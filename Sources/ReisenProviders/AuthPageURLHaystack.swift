import Foundation

public enum AuthPageURLHaystack {
    public static func classificationHaystack(for absoluteURL: String) -> String {
        AuthPageURLClassification.haystack(for: absoluteURL)
    }

    public static func containsAnyMarker(_ haystack: String, _ markers: [String]) -> Bool {
        AuthPageURLMarkerScan.containsAnyMarker(haystack, markers)
    }

    public static func containsMarker(_ haystack: String, _ marker: String) -> Bool {
        AuthPageURLMarkerScan.containsMarker(haystack, marker)
    }
}
