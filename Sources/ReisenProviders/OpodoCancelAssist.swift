import Foundation
import ReisenDomain

/// Opodo cancel assist: open confirm dialog on trip details; never confirm storno.
public enum OpodoCancelAssist {
    public static let component = "OpodoCancelAssist"
    public static let portalHost = "opodo.de"

    public static func shouldRun(provider: ProviderID, loadedURL: URL?) -> Bool {
        guard provider == .opodo else { return false }
        return isTripDetailsURL(loadedURL)
    }

    public static func isTripDetailsURL(_ url: URL?) -> Bool {
        guard let url, let host = url.host?.lowercased(), isOpodoPortalHost(host) else {
            return false
        }
        let fragment = url.fragment ?? ""
        return fragment.lowercased().contains("tripdetails")
    }

    /// Exact host or subdomain of `opodo.de` (no lookalike substring).
    public static func isOpodoPortalHost(_ host: String) -> Bool {
        let h = host.lowercased()
        return h == portalHost || h.hasSuffix("." + portalHost)
    }
}
