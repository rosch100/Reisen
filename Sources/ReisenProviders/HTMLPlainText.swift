import Foundation

/// Strip tags / common entities and collapse whitespace to plain text (SSOT for stay-hint extractors).
public enum HTMLPlainText {
    private static let tagPattern = try? NSRegularExpression(pattern: "<[^>]+>", options: [])

    public static func flatten(_ html: String) -> String {
        var s = html
        if let regex = tagPattern {
            s = regex.stringByReplacingMatches(
                in: s,
                options: [],
                range: NSRange(s.startIndex..., in: s),
                withTemplate: " "
            )
        }
        return s
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
