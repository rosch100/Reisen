import Foundation

/// SSOT: `Resources/github-issue-secret-redactor.rules.json` (App + Gmail-Ingress).
public enum GitHubIssueSecretRedactorRules {
    public struct Rule: Sendable, Equatable, Decodable {
        public let pattern: String
        public let template: String
    }

    public static let markdownCodeFenceMinLength = file.markdownCodeFenceMinLength
    public static let rules = file.rules

    static let resourceName = "github-issue-secret-redactor.rules"

    private struct File: Decodable {
        let markdownCodeFenceMinLength: Int
        let rules: [Rule]
    }

    private static let file: File = loadFile()

    private static func loadFile() -> File {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "json") else {
            preconditionFailure("\(resourceName).json fehlt im ReisenDomain-Bundle.")
        }
        do {
            let decoded = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
            guard decoded.markdownCodeFenceMinLength >= 3, !decoded.rules.isEmpty else {
                preconditionFailure("\(resourceName).json: Fence-Minimum oder Regeln ungültig.")
            }
            return decoded
        } catch {
            preconditionFailure("\(resourceName).json unlesbar: \(error)")
        }
    }
}
