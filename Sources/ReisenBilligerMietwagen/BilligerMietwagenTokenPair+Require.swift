import Foundation
import ReisenDomain
import ReisenProviders

extension BilligerMietwagenTokenPair {
    func requiringSessionTokens() throws -> (access: String, refresh: String) {
        try requiringBothTokens(orThrow: .sessionNotAuthenticated)
    }

    /// Refresh-Antwort: beide Tokens non-empty (kein Fallback auf den alten Refresh).
    func requiringRefreshedTokens() throws -> (access: String, refresh: String) {
        try requiringBothTokens(orThrow: .tokenRefreshFailed)
    }

    private func requiringBothTokens(
        orThrow error: BilligerMietwagenProviderError
    ) throws -> (access: String, refresh: String) {
        guard let access = NonEmpty.string(accessToken),
              let refresh = NonEmpty.string(refreshToken)
        else {
            throw error
        }
        return (access, refresh)
    }
}
