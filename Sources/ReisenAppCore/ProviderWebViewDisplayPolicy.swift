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
    public static func allowsEmbed(
        owner: ProviderWebViewDisplayOwner,
        host: ProviderWebViewHostRole
    ) -> Bool {
        switch owner {
        case .syncHost:
            return host == .probe || host == .sync
        case .cancelSheet:
            return host == .cancelSheet
        }
    }
}
