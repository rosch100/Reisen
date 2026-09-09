import ReisenDomain

public enum ProviderWebViewDisplayOwner: Equatable, Sendable {
    case syncHost
    case cancelSheet
}

public enum ProviderWebViewHostRole: Equatable, Sendable {
    case probe
    case sync
    case cancelSheet
}

public enum ProviderWebViewDisplayPolicy {
    /// - Parameters:
    ///   - providerID: Host-Provider (nötig für Probe-vs-Foreground-Ausschluss).
    ///   - foregroundSyncProviderID: Provider, dessen WebView der sichtbare Sync-Host hält.
    public static func allowsEmbed(
        owner: ProviderWebViewDisplayOwner,
        host: ProviderWebViewHostRole,
        providerID: ProviderID? = nil,
        foregroundSyncProviderID: ProviderID? = nil
    ) -> Bool {
        switch owner {
        case .syncHost:
            switch host {
            case .probe:
                if let providerID, providerID == foregroundSyncProviderID {
                    return false
                }
                return true
            case .sync:
                return true
            case .cancelSheet:
                return false
            }
        case .cancelSheet:
            return host == .cancelSheet
        }
    }
}
