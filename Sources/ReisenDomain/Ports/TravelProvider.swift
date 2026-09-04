import Foundation

public protocol ProviderSession: AnyObject {}

@MainActor
public protocol TravelProviderProgressReporting: AnyObject {
    var onProgress: (@MainActor (String) -> Void)? { get set }
}

@MainActor
public protocol TravelProvider {
    var id: ProviderID { get }
    var displayName: String { get }

    func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog
    func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment

    func needsDraftEnrichment(
        draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool
}

extension TravelProvider {
    public func needsDraftEnrichment(
        draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool {
        DraftEnrichmentNeeds.shouldEnrich(draft, requiresDeadlines: requiresDeadlines)
    }
}

/// Optional login metadata for provider web-based account syncing.
@MainActor
public protocol TravelProviderLoginConfiguration {
    var loginURL: URL { get }
    var keychainServerHost: String { get }
    /// Hosts, die Keychain-Passwort-Autofill erhalten dürfen (Default: nur `keychainServerHost`).
    var passwordAutofillAllowedHosts: [String] { get }
}

extension TravelProviderLoginConfiguration {
    public var passwordAutofillAllowedHosts: [String] { [keychainServerHost] }
}
