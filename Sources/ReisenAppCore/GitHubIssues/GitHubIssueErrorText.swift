import Foundation

enum GitHubIssueErrorText {
    private static let maxUnderlyingDepth = 8

    static let userInfoKeys: [String] = [
        NSLocalizedDescriptionKey,
        NSLocalizedFailureReasonErrorKey,
        NSLocalizedRecoverySuggestionErrorKey,
        NSDebugDescriptionErrorKey,
        NSURLErrorKey,
        NSUnderlyingErrorKey,
    ]

    static func dump(_ error: Error) -> String {
        SecretRedactor.redact(rawDump(error))
    }

    private static func rawDump(_ error: Error) -> String {
        var lines: [String] = []
        lines.append("Typ: \(type(of: error))")
        appendNSError(error as NSError, into: &lines, prefix: "", depth: 0)
        return lines.joined(separator: "\n")
    }

    private static func appendNSError(
        _ ns: NSError,
        into lines: inout [String],
        prefix: String,
        depth: Int
    ) {
        lines.append("\(prefix)Domain: \(ns.domain)")
        lines.append("\(prefix)Code: \(ns.code)")
        if !ns.localizedDescription.isEmpty {
            lines.append("\(prefix)Meldung: \(ns.localizedDescription)")
        }
        if let reason = ns.localizedFailureReason, !reason.isEmpty {
            lines.append("\(prefix)Grund: \(reason)")
        }
        if let suggestion = ns.localizedRecoverySuggestion, !suggestion.isEmpty {
            lines.append("\(prefix)Hinweis: \(suggestion)")
        }
        if let debug = ns.userInfo[NSDebugDescriptionErrorKey] as? String, !debug.isEmpty {
            lines.append("\(prefix)DebugDescription: \(debug)")
        }
        if let value = ns.userInfo[NSURLErrorKey], let url = urlText(value) {
            lines.append("\(prefix)URL: \(url)")
        }
        guard depth < maxUnderlyingDepth else { return }
        guard let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError else { return }
        lines.append("\(prefix)Underlying:")
        appendNSError(underlying, into: &lines, prefix: prefix + "  ", depth: depth + 1)
    }

    static func urlText(_ value: Any) -> String? {
        if let url = value as? URL {
            return url.absoluteString
        }
        if let text = value as? String, !text.isEmpty {
            return text
        }
        return nil
    }
}
