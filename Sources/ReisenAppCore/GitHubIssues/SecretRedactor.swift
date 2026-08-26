import Foundation

public enum SecretRedactor {
    public static func redact(_ text: String) -> String {
        var result = text
        result = replace(result, pattern: #"(?i)(Authorization:\s*Bearer\s+)\S+"#, template: "$1[redacted]")
        result = replace(result, pattern: #"(?i)(Bearer\s+)(?:ghp_|github_pat_)[A-Za-z0-9_]+"#, template: "$1[redacted]")
        result = replace(result, pattern: #"github_pat_[A-Za-z0-9_]+"#, template: "[redacted]")
        result = replace(result, pattern: #"ghp_[A-Za-z0-9]+"#, template: "[redacted]")
        result = replace(result, pattern: #"(?i)(Cookie:\s*)\S.*"#, template: "$1[redacted]")
        result = replace(
            result,
            pattern: #"(?i)([?&](?:code|token|session|password)=)[^&\s]+"#,
            template: "$1[redacted]"
        )
        result = replace(
            result,
            pattern: #"(?i)(\"(?:access_token|refresh_token|id_token|api[_-]?key|token|session|password|authorization|sentinel)\"\s*:\s*\")[^\"]*(\")"#,
            template: "$1[redacted]$2"
        )
        result = replace(
            result,
            pattern: #"(?i)\b(sen_t|tvs|tvl|tvo|clientSessionId|tv-clientsessionid)\s*[:=]\s*[^;\s&]+"#,
            template: "$1=[redacted]"
        )
        return result
    }

    private static func replace(_ text: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }
}
