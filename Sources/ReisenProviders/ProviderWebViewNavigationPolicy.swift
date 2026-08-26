import Foundation

/// Entscheidet, ob eine Navigation in der eingebetteten Provider-WebView erlaubt ist.
/// Verhindert Absprung in native Apps, App Store oder Custom-Scheme-Trampolines.
public enum ProviderWebViewNavigationPolicy: Sendable {
    public enum Decision: Equatable, Sendable {
        case allow
        case cancel
    }

    private static let allowedSchemes: Set<String> = [
        "http", "https", "about", "blob", "data",
    ]

    private static let blockedStoreHostSuffixes = [
        "apps.apple.com",
        "itunes.apple.com",
    ]

    public static func allows(_ url: URL, isMainFrame: Bool) -> Bool {
        decision(for: url, isMainFrame: isMainFrame) == .allow
    }

    public static func decision(for url: URL, isMainFrame: Bool) -> Decision {
        guard let scheme = url.scheme?.lowercased() else { return .cancel }
        guard allowedSchemes.contains(scheme) else { return .cancel }
        if isMainFrame, scheme == "https", isBlockedStoreHost(url) {
            return .cancel
        }
        return .allow
    }

    private static func isBlockedStoreHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return blockedStoreHostSuffixes.contains { host == $0 || host.hasSuffix(".\($0)") }
    }
}
