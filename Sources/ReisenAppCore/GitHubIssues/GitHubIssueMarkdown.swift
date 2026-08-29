import ReisenDomain

enum GitHubIssueMarkdown {
    private static let formFieldTruncationSuffix = """

    … (Text gekürzt — vollständige Meldung steht in der App.)
    """

    private static let sectionHeadingDelimiter = "\n" + GitHubRepository.issueMarkdownH2Prefix

    static func sectionHeading(_ title: String) -> String {
        GitHubRepository.issueMarkdownH2Prefix + title
    }

    static func fence(_ text: String) -> String {
        let ticks = String(repeating: "`", count: fenceTickCount(in: text))
        return "\(ticks)\n\(text)\n\(ticks)"
    }

    private static func wrappingOverhead(for text: String) -> Int {
        2 * fenceTickCount(in: text) + 2
    }

    static func truncated(_ text: String, maxCharacters: Int, suffix: String = formFieldTruncationSuffix) -> String {
        guard text.count > maxCharacters else { return text }
        let keep = max(0, maxCharacters - suffix.count)
        return String(text.prefix(keep)) + suffix
    }

    static func fenceFitting(_ text: String, maxCharacters: Int) -> String {
        guard maxCharacters > 0 else { return "" }
        var maxInner = max(0, maxCharacters - wrappingOverhead(for: text))
        var inner = truncated(text, maxCharacters: maxInner)
        var fenced = fence(inner)
        while fenced.count > maxCharacters && maxInner > 0 {
            maxInner = max(0, maxInner - max(1, fenced.count - maxCharacters))
            inner = truncated(text, maxCharacters: maxInner)
            fenced = fence(inner)
        }
        return fenced
    }

    static func prefixFittingSectionHeadings(_ body: String, maxCharacters: Int) -> String {
        guard body.count > maxCharacters else { return body }
        let prefix = String(body.prefix(maxCharacters))
        let chunks = body.components(separatedBy: sectionHeadingDelimiter)
        guard chunks.count > 1 else { return prefix }
        var sections = [chunks[0]]
        sections.append(contentsOf: chunks.dropFirst().map { sectionHeadingDelimiter + $0 })
        var acc = ""
        for section in sections {
            if acc.count + section.count > maxCharacters { break }
            acc += section
        }
        return acc.isEmpty ? prefix : acc
    }

    private static func fenceTickCount(in text: String) -> Int {
        max(GitHubIssueSecretRedactorRules.markdownCodeFenceMinLength, longestBacktickRun(in: text) + 1)
    }

    private static func longestBacktickRun(in text: String) -> Int {
        var longest = 0
        var current = 0
        for character in text {
            if character == "`" {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }
}
