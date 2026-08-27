import Foundation

public enum ProviderDeepLinks {
    public static func suggestions(
        for gap: ComputedGap,
        preferredProvider: ProviderID?,
        deepLinkBuilder: (ProviderID) -> (any GapDeepLinkBuilding)?,
        allBuilders: [any GapDeepLinkBuilding]
    ) -> [DeepLinkSuggestion] {
        let context = GapContext(gap: gap)
        let builders = selectedBuilders(
            preferredProvider: preferredProvider,
            deepLinkBuilder: deepLinkBuilder,
            allBuilders: allBuilders
        )
        return suggestions(for: context, allBuilders: builders).links
    }

    public static func suggestions(
        for context: GapContext,
        allBuilders: [any GapDeepLinkBuilding]
    ) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        var links: [DeepLinkSuggestion] = []
        var issues: [DeepLinkIssue] = []
        for builder in allBuilders {
            let result = builder.suggestions(for: context)
            links.append(contentsOf: result.links.filter { $0.url != nil })
            issues.append(contentsOf: result.issues)
        }
        return (links, issues)
    }

    public static func shouldShow(_ suggestion: DeepLinkSuggestion, gapKind: GapKind) -> Bool {
        let isHotel = suggestion.title.localizedCaseInsensitiveContains("hotel")
        if !isHotel { return true }
        return gapKind == .lodging || gapKind == .both
    }

    public static func openableLinks(
        _ links: [DeepLinkSuggestion],
        gapKind: GapKind
    ) -> [(suggestion: DeepLinkSuggestion, url: URL)] {
        links.compactMap { suggestion in
            guard let url = suggestion.url,
                  shouldShow(suggestion, gapKind: gapKind) else { return nil }
            return (suggestion, url)
        }
    }

    public static func issuesMessage(_ issues: [DeepLinkIssue]) -> String? {
        let message = issues.compactMap(\.errorDescription).joined(separator: " ")
        return message.isEmpty ? nil : message
    }

    private static func selectedBuilders(
        preferredProvider: ProviderID?,
        deepLinkBuilder: (ProviderID) -> (any GapDeepLinkBuilding)?,
        allBuilders: [any GapDeepLinkBuilding]
    ) -> [any GapDeepLinkBuilding] {
        if let preferredProvider,
           let builder = deepLinkBuilder(preferredProvider) {
            return [builder]
        }
        return allBuilders
    }
}
