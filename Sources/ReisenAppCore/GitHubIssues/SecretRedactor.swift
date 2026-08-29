import Foundation
import ReisenDomain

/// Anonymisiert Geheimnisse und Personenbezüge in Texten, die die App verlassen
/// (öffentliche GitHub-Issues, Crash-Pending-Datei).
///
/// Muster: `GitHubIssueSecretRedactorRules` / `github-issue-secret-redactor.rules.json`.
public enum SecretRedactor {
    public static func redact(_ text: String) -> String {
        rules.reduce(text, apply)
    }

    private struct Rule {
        let regex: NSRegularExpression
        let template: String
    }

    private static let rules: [Rule] = GitHubIssueSecretRedactorRules.rules.map(compile)

    private static func compile(_ spec: GitHubIssueSecretRedactorRules.Rule) -> Rule {
        do {
            return Rule(
                regex: try NSRegularExpression(pattern: spec.pattern),
                template: spec.template
            )
        } catch {
            preconditionFailure("SecretRedactor-Muster ungültig: \(spec.pattern): \(error)")
        }
    }

    private static func apply(_ text: String, _ rule: Rule) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return rule.regex.stringByReplacingMatches(in: text, range: range, withTemplate: rule.template)
    }
}
