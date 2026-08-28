import Foundation
import ReisenDomain
import ReisenProviders

extension BilligerMietwagenTokenPair {
    func requiringSessionTokens() throws -> (access: String, refresh: String) {
        try requiringBothTokens(orThrow: .sessionNotAuthenticated)
    }

    /// Live-Refresh (201): oft nur `access_token`/`id_token`. Rotierter Refresh
    /// wenn vorhanden, sonst der soeben erfolgreiche Session-Refresh (SPA-Parität).
    func requiringRefreshedTokens(reusingRefresh previous: String) throws -> (access: String, refresh: String) {
        guard let access = NonEmpty.string(accessToken) else {
            throw BilligerMietwagenProviderError.tokenRefreshFailed
        }
        if let rotated = NonEmpty.string(refreshToken) {
            return (access, rotated)
        }
        guard let previous = NonEmpty.string(previous) else {
            throw BilligerMietwagenProviderError.tokenRefreshFailed
        }
        return (access, previous)
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
