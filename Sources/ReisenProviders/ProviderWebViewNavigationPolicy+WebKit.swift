import WebKit

extension ProviderWebViewNavigationPolicy {
    /// Mappt die Domain-Entscheidung auf `WKNavigationActionPolicy`.
    /// Fehlende URL bleibt erlaubt — wie die bisherigen Delegate-Guards (`if let url`).
    public static func navigationActionPolicy(
        url: URL?,
        isMainFrame: Bool
    ) -> WKNavigationActionPolicy {
        guard let url else { return .allow }
        switch decision(for: url, isMainFrame: isMainFrame) {
        case .allow:
            return .allow
        case .cancel:
            return .cancel
        }
    }
}
