import Foundation
import CryptoKit

public enum GitHubIssueFingerprint {
    public static func hex(kind: GitHubIssueKind, message: String) -> String {
        let material = "\(kind.rawValue)\n\(normalizedMessage(message))"
        let digest = SHA256.hash(data: Data(material.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func normalizedMessage(_ message: String) -> String {
        let withoutDates = message.replacingOccurrences(
            of: #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z?"#,
            with: "",
            options: .regularExpression
        )
        let collapsed = withoutDates.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
