import Foundation

extension Check24DeepLinkBuilder {
    func extractIATAToken(from trimmed: String) -> String? {
        let pattern = #"\b[A-Z]{3}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let upper = trimmed.uppercased() as NSString
        let matches = regex.matches(
            in: trimmed.uppercased(),
            options: [],
            range: NSRange(location: 0, length: upper.length)
        )
        guard let match = matches.first else { return nil }
        return upper.substring(with: match.range)
    }
}
