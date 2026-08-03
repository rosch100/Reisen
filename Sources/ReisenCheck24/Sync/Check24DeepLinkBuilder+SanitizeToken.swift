import Foundation

extension Check24DeepLinkBuilder {
    func sanitizeFlightSearchToken(_ trimmed: String) -> String? {
        let upper = trimmed.uppercased()
        let sanitized = upper
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: #"[^A-Z0-9\-]"#, with: "", options: .regularExpression)
        guard !sanitized.isEmpty else { return nil }
        return sanitized
    }
}
