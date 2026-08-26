import Foundation

extension OpodoTripCancellationGraphQLParser {
    public static func looksCancelled(inPageText text: String) -> Bool {
        let lower = text.lowercased()
        // Bewusst „storniert“ / „cancelled“, nicht „Stornierungsrichtlinie“ / „cancellation“.
        if lower.contains("storniert") { return true }
        if lower.range(of: #"\bcancelled\b"#, options: .regularExpression) != nil { return true }
        if lower.contains("booking canceled") || lower.contains("booking cancelled") { return true }
        return false
    }
}
