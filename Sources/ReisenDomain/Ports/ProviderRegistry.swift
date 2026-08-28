import Foundation

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

    /// App-Store-Build ohne Provider-Abruf (nur iCloud/Manuell).
    public static let empty = ProviderRegistry(providers: [], deepLinkBuilders: [])

    public var syncProviderIDs: [ProviderID] {
        providers.map(\.id)
    }

    public func enabledSyncProviderIDs(defaults: UserDefaults = .standard) -> [ProviderID] {
        syncProviderIDs.filter { AppSettingsKeys.isProviderEnabled($0, defaults: defaults) }
    }

    public var gapSearchProviderIDs: [ProviderID] {
        deepLinkBuilders.map(\.providerID)
    }

    public func enabledGapSearchProviderIDs(defaults: UserDefaults = .standard) -> [ProviderID] {
        let enabled = Set(enabledSyncProviderIDs(defaults: defaults))
        return gapSearchProviderIDs.filter { enabled.contains($0) }
    }

    public func provider(id: ProviderID) -> (any TravelProvider)? {
        providers.first { $0.id == id }
    }

    public func deepLinkBuilder(id: ProviderID) -> (any GapDeepLinkBuilding)? {
        deepLinkBuilders.first { $0.providerID == id }
    }

    public func deepLinks(
        for gap: ComputedGap,
        preferredProvider: ProviderID? = nil,
        defaults: UserDefaults = .standard
    ) -> [DeepLinkSuggestion] {
        ProviderDeepLinks.suggestions(
            for: gap,
            preferredProvider: preferredProvider,
            enabledProviderIDs: Set(enabledSyncProviderIDs(defaults: defaults)),
            deepLinkBuilder: { deepLinkBuilder(id: $0) },
            allBuilders: deepLinkBuilders
        )
    }

    public func gapDeepLinkSuggestions(
        for context: GapContext,
        preferredProvider: ProviderID? = nil,
        defaults: UserDefaults = .standard
    ) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        ProviderDeepLinks.suggestions(
            for: context,
            allBuilders: selectedGapBuilders(preferredProvider: preferredProvider, defaults: defaults)
        )
    }

    public func gapDeepLinkSuggestions(
        for gap: ComputedGap,
        kind: GapKind,
        preferredProvider: ProviderID? = nil,
        defaults: UserDefaults = .standard
    ) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        gapDeepLinkSuggestions(
            for: GapContext(gap: gap, kind: kind),
            preferredProvider: preferredProvider,
            defaults: defaults
        )
    }

    private func selectedGapBuilders(
        preferredProvider: ProviderID?,
        defaults: UserDefaults
    ) -> [any GapDeepLinkBuilding] {
        ProviderDeepLinks.selectedBuilders(
            preferredProvider: preferredProvider,
            enabledProviderIDs: Set(enabledSyncProviderIDs(defaults: defaults)),
            deepLinkBuilder: { deepLinkBuilder(id: $0) },
            allBuilders: deepLinkBuilders
        )
    }
}
