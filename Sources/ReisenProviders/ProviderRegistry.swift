import Foundation
import ReisenDomain

public protocol GapDeepLinkBuilding: Sendable {
    var providerID: ProviderID { get }
    func suggestions(for gap: GapContext) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue])
}

@MainActor
public struct ProviderRegistry {
    public let providers: [any TravelProvider]
    public let deepLinkBuilders: [any GapDeepLinkBuilding]

    public init(
        providers: [any TravelProvider],
        deepLinkBuilders: [any GapDeepLinkBuilding] = []
    ) {
        self.providers = providers
        self.deepLinkBuilders = deepLinkBuilders
    }

    public var syncProviderIDs: [ProviderID] {
        providers.map(\.id)
    }

    public func enabledSyncProviderIDs(defaults: UserDefaults = .standard) -> [ProviderID] {
        syncProviderIDs.filter { AppSettingsKeys.isProviderEnabled($0, defaults: defaults) }
    }

    public func provider(id: ProviderID) -> (any TravelProvider)? {
        providers.first { $0.id == id }
    }

    public func deepLinkBuilder(id: ProviderID) -> (any GapDeepLinkBuilding)? {
        deepLinkBuilders.first { $0.providerID == id }
    }

    public func deepLinks(for gap: ComputedGap, preferredProvider: ProviderID? = nil) -> [DeepLinkSuggestion] {
        ProviderDeepLinks.suggestions(
            for: gap,
            preferredProvider: preferredProvider,
            deepLinkBuilder: { deepLinkBuilder(id: $0) },
            allBuilders: deepLinkBuilders
        )
    }

    public func gapDeepLinkSuggestions(for context: GapContext) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        ProviderDeepLinks.suggestions(for: context, allBuilders: deepLinkBuilders)
    }

    public func gapDeepLinkSuggestions(
        for gap: ComputedGap,
        kind: GapKind
    ) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        gapDeepLinkSuggestions(for: GapContext(gap: gap, kind: kind))
    }
}
