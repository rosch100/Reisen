import Foundation

/// Anonymisiert Geheimnisse und Personenbezüge in Texten, die die App verlassen
/// (öffentliche GitHub-Issues, Crash-Pending-Datei).
public enum SecretRedactor {
    public static func redact(_ text: String) -> String {
        rules.reduce(text, apply)
    }

    private struct Rule {
        let regex: NSRegularExpression
        let template: String
    }

    private static let jsonIdentityKeys = [
        "givenName", "familyName", "secondFamilyName", "firstName", "lastName",
        "fullName", "displayName", "birthDate", "email", "phoneNumber", "phone",
        "mobile", "address", "street", "postalCode", "zipCode", "passportNumber", "passport", "iban",
    ]

    private static let queryIdentityKeys = [
        "email", "firstName", "lastName", "givenName", "familyName",
        "phone", "mobile", "address", "street", "passenger",
    ]

    private static let rules: [Rule] = makeRules()

    private static func makeRules() -> [Rule] {
        compile([
            (#"(?i)(Authorization:\s*Bearer\s+)\S+"#, "$1[redacted]"),
            (#"(?i)(Bearer\s+)(?:ghp_|github_pat_)[A-Za-z0-9_]+"#, "$1[redacted]"),
            (#"github_pat_[A-Za-z0-9_]+"#, "[redacted]"),
            (#"ghp_[A-Za-z0-9]+"#, "[redacted]"),
            (#"(?i)(Cookie:\s*)\S.*"#, "$1[redacted]"),
            (#"(?i)([?&](?:code|token|session|password)=)[^&\s]+"#, "$1[redacted]"),
            (
                #"(?i)(\"(?:access_token|refresh_token|id_token|api[_-]?key|token|session|password|authorization|sentinel)\"\s*:\s*\")[^\"]*(\")"#,
                "$1[redacted]$2"
            ),
            (
                #"(?i)\b(sen_t|tvs|tvl|tvo|clientSessionId|tv-clientsessionid)\s*[:=]\s*[^;\s&]+"#,
                "$1=[redacted]"
            ),
            (
                #"(?i)(\"(?:confirmationCode|confirmation_code|bookingNumber|booking_number|pnr)\"\s*:\s*\")[^\"]*(\")"#,
                "$1[redacted]$2"
            ),
            (
                #"(?i)\b((?:buchungs(?:nummer|nr|code)|vorgangsnummer|confirmation(?:\s*code)?|confirmationcode|booking\s*(?:ref(?:erence)?|number|code)|pnr|record\s*locator)\s*[:=]?\s*)[A-Z0-9-]{4,}"#,
                "$1[redacted]"
            ),
            jsonQuotedValues(jsonIdentityKeys),
            queryValues(queryIdentityKeys),
            (
                #"(?i)\b((?:vorname|nachname|familienname|given\s*name|family\s*name|first\s*name|last\s*name)\s*[:=]\s*)[^\s&?,;]+"#,
                "$1[redacted]"
            ),
            (#"(?i)\b((?:adresse|address)\s*[:=]\s*)[^\n]+"#, "$1[redacted]"),
            (
                #"(?i)\b((?:telefon|tel\.?|phone|handy|mobilfunk(?:nummer)?|mobile)\s*[:=]\s*)[+\d][\d\s/().-]{5,}"#,
                "$1[redacted]"
            ),
            (
                #"(?i)\b((?:geburtsdatum|birth(?:\s*date)?|date of birth|dob)\s*[:=]\s*)[\d./-]{6,10}"#,
                "$1[redacted]"
            ),
            (
                #"(?i)\b((?:passnummer|reisepass|passport(?:\s*no(?:umber)?)?)\s*[:=]\s*)\S+"#,
                "$1[redacted]"
            ),
            (#"(?i)[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#, "[redacted]"),
            (#"\+\d{1,3}(?:[\s./-]?\d{2,4}){2,4}"#, "[redacted]"),
            (#"\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]){10,30}\b"#, "[redacted]"),
            (#"(?i)\b[\p{L}]+(?:straße|strasse|str\.|weg|platz|allee)\s+\d+[a-z]?"#, "[redacted]"),
            (#"(?i)(/(?:Users|home)/)[^/\s]+"#, "$1[redacted]"),
        ])
    }

    private static func jsonQuotedValues(_ keys: [String]) -> (String, String) {
        (#"(?i)(\"(?:\#(keys.joined(separator: "|")))\"\s*:\s*\")[^\"]*(\")"#, "$1[redacted]$2")
    }

    private static func queryValues(_ keys: [String]) -> (String, String) {
        (#"(?i)([?&](?:\#(keys.joined(separator: "|")))=)[^&\s]+"#, "$1[redacted]")
    }

    private static func compile(_ specs: [(String, String)]) -> [Rule] {
        specs.map { pattern, template in
            do {
                return Rule(regex: try NSRegularExpression(pattern: pattern), template: template)
            } catch {
                preconditionFailure("SecretRedactor-Muster ungültig: \(pattern): \(error)")
            }
        }
    }

    private static func apply(_ text: String, _ rule: Rule) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return rule.regex.stringByReplacingMatches(in: text, range: range, withTemplate: rule.template)
    }
}
