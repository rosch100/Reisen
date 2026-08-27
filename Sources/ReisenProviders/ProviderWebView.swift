import WebKit
import ReisenDomain

public enum ProviderWebViewError: Error, Equatable, Sendable, LocalizedError {
    case missingSession

    public var errorDescription: String? {
        switch self {
        case .missingSession:
            return "Die Provider-Session enthält keine WebView."
        }
    }
}

public enum ProviderWebView {
    @MainActor
    public static func unwrap(_ session: any ProviderSession) -> WKWebView? {
        (session as? WebViewProviderSession)?.webView
    }

    @MainActor
    public static func webView<E: Error>(
        from session: any ProviderSession,
        orThrow error: @autoclosure () -> E
    ) throws -> WKWebView {
        guard let web = unwrap(session) else {
            throw error()
        }
        return web
    }

    @MainActor
    public static func webView(from session: any ProviderSession) throws -> WKWebView {
        try webView(from: session, orThrow: ProviderWebViewError.missingSession)
    }
}
