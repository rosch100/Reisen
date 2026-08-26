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

    func firstDateInSnippet(_ snippet: String) -> Date? {
        if let iso = parseISODateFromSnippet(snippet) { return iso }
        if let bis = parseOpodoBisDateFromSnippet(snippet) { return bis }
        if let deDateTime = parseDeDateTimeFromSnippet(snippet) { return deDateTime }
        if let deDate = parseDeDateFromSnippet(snippet) { return deDate }
        return nil
    }
}
