import Foundation

/// Visible plain text from HTML: drop script/style, tags, entities; collapse whitespace.
/// SSOT for stay-hint extractors and Traveloka policy HTML.
public enum HTMLPlainText {
    public static func flatten(_ html: String) -> String {
        var s = stripHiddenMarkup(html)
        if let tagPattern {
            s = replacingMatches(tagPattern, in: s)
        }
        return s
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// i18n-JSON in `<script>` is not guest-visible policy text.
    private static func stripHiddenMarkup(_ html: String) -> String {
        hiddenMarkupPatterns.reduce(html) { replacingMatches($1, in: $0) }
    }

    private static func replacingMatches(_ regex: NSRegularExpression, in text: String) -> String {
        regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text),
            withTemplate: " "
        )
    }

    private static let tagPattern = regex("<[^>]+>")

    private static let hiddenMarkupPatterns: [NSRegularExpression] = [
        "<script\\b[^>]*>[\\s\\S]*?</script>",
        "<style\\b[^>]*>[\\s\\S]*?</style>",
    ].compactMap { regex($0, options: .caseInsensitive) }

    private static func regex(
        _ pattern: String,
        options: NSRegularExpression.Options = []
    ) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: options)
    }
}
