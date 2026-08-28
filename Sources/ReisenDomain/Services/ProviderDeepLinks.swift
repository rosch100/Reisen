import Foundation

public enum ProviderDeepLinks {
    public static func suggestions(
        for gap: ComputedGap,
        preferredProvider: ProviderID?,
        enabledProviderIDs: Set<ProviderID>,
        deepLinkBuilder: (ProviderID) -> (any GapDeepLinkBuilding)?,
        allBuilders: [any GapDeepLinkBuilding]
    ) -> [DeepLinkSuggestion] {
        let context = GapContext(gap: gap)
        let builders = selectedBuilders(
            preferredProvider: preferredProvider,
            enabledProviderIDs: enabledProviderIDs,
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
            // Builder sollen nur passende Kategorien liefern; hier zusätzlich absichern.
            links.append(contentsOf: result.links.filter {
                $0.url != nil && shouldShow($0, gapKind: context.kind)
            })
            issues.append(contentsOf: result.issues.filter { $0.isVisible(for: context.kind) })
        }
        return (links, uniqueIssues(issues))
    }

    public static func shouldShow(_ suggestion: DeepLinkSuggestion, gapKind: GapKind) -> Bool {
        suggestion.category.isVisible(for: gapKind)
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

    public static func selectedBuilders(
        preferredProvider: ProviderID?,
        enabledProviderIDs: Set<ProviderID>,
        deepLinkBuilder: (ProviderID) -> (any GapDeepLinkBuilding)?,
        allBuilders: [any GapDeepLinkBuilding]
    ) -> [any GapDeepLinkBuilding] {
        let enabledBuilders = allBuilders.filter { enabledProviderIDs.contains($0.providerID) }
        // Ungültiges Preferred (deaktiviert / kein Builder) wie „Alle Aktiven“ —
        // sonst UI-Picker „Alle“ bei stale State und leere Such-Links.
        if let preferredProvider,
           enabledProviderIDs.contains(preferredProvider),
           let builder = deepLinkBuilder(preferredProvider) {
            return [builder]
        }
        return enabledBuilders
    }

    private static func uniqueIssues(_ issues: [DeepLinkIssue]) -> [DeepLinkIssue] {
        var seen = Set<DeepLinkIssue>()
        return issues.filter { seen.insert($0).inserted }
    }
}
