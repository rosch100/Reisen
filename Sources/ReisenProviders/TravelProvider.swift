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

// ProviderRegistry & GapDeepLinkBuilding live in `ProviderRegistry.swift` (SSOT).
