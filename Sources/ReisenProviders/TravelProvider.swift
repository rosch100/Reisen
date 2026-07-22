import Foundation
import ReisenDomain

public protocol ProviderSession: AnyObject {}

@MainActor
public protocol TravelProvider {
    var id: ProviderID { get }
    var displayName: String { get }

    func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog
    func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment
}

/// Optional login metadata for provider web-based account syncing.
@MainActor
public protocol TravelProviderLoginConfiguration {
    /// URL used to start the provider's login flow in the embedded web view.
    var loginURL: URL { get }
    /// Keychain server host used for credential lookup (Internet password entry).
    var keychainServerHost: String { get }
}

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

    public func provider(id: ProviderID) -> (any TravelProvider)? {
        providers.first { $0.id == id }
    }

    public func deepLinkBuilder(id: ProviderID) -> (any GapDeepLinkBuilding)? {
        deepLinkBuilders.first { $0.providerID == id }
    }

    public func deepLinks(for gap: ComputedGap, preferredProvider: ProviderID? = nil) -> [DeepLinkSuggestion] {
        let context = GapContext(gap: gap)
        let builders: [any GapDeepLinkBuilding]
        if let preferredProvider, let builder = deepLinkBuilder(id: preferredProvider) {
            builders = [builder]
        } else {
            builders = deepLinkBuilders
        }
        return builders.flatMap { $0.suggestions(for: context).links.filter { $0.url != nil } }
    }
}
