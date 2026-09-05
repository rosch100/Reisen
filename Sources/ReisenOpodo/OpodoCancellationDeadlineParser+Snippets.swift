import Foundation

extension OpodoCancellationDeadlineParser {
    func isFreeCancellation(in snippet: String) -> Bool {
        let lower = snippet.lowercased()
        return lower.contains("free cancellation")
            || lower.contains("free cancel")
            || lower.contains("for free")
            || lower.contains("full refund")
            || lower.contains("100 %")
            || lower.contains("100%")
    }

    func firstDateInSnippet(_ snippet: String) -> (date: Date, offsetSeconds: Int?)? {
        if let iso = parseISODateFromSnippet(snippet) { return iso }
        // DE/Wall-Clock ohne Offset-Marker: Opodo-UI-Konvention `0` (nicht Geräte-TZ).
        if let bis = parseOpodoBisDateFromSnippet(snippet) { return (bis, 0) }
        if let deDateTime = parseDeDateTimeFromSnippet(snippet) { return (deDateTime, 0) }
        if let deDate = parseDeDateFromSnippet(snippet) { return (deDate, 0) }
        return nil
    }
}
