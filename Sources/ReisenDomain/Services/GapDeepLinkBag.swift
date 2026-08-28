import Foundation

/// Sammelt Gap-Such-Links/Issues eines Providers mit GapKind-Filter (SSOT für Builder).
public struct GapDeepLinkBag {
    public private(set) var links: [DeepLinkSuggestion] = []
    public private(set) var issues: [DeepLinkIssue] = []

    private let providerID: ProviderID
    private let kind: GapKind

    public init(providerID: ProviderID, kind: GapKind) {
        self.providerID = providerID
        self.kind = kind
    }

    public mutating func add(
        _ category: GapSearchCategory,
        url: URL?,
        missing: DeepLinkIssue
    ) {
        guard category.isVisible(for: kind) else { return }
        if let url {
            links.append(DeepLinkSuggestion(category: category, providerID: providerID, url: url))
        } else {
            appendIssue(missing)
        }
    }

    public mutating func add(
        _ category: GapSearchCategory,
        make: () throws -> URL,
        fallback: DeepLinkIssue
    ) {
        guard category.isVisible(for: kind) else { return }
        do {
            let url = try make()
            links.append(DeepLinkSuggestion(category: category, providerID: providerID, url: url))
        } catch let issue as DeepLinkIssue {
            appendIssue(issue)
        } catch {
            appendIssue(fallback)
        }
    }

    public var result: (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        (links, issues)
    }

    private mutating func appendIssue(_ issue: DeepLinkIssue) {
        if !issues.contains(issue) {
            issues.append(issue)
        }
    }
}
