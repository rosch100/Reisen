import Foundation
import WebKit

/// Wartet auf Navigation-Abschluss, **ohne** den bestehenden `navigationDelegate` zu stehlen.
/// SwiftUI/`ProviderSessionView` setzt den Delegate sonst zurück → Timeout (NavigationAwaiter-Fehler 1),
/// obwohl die Seite bereits geladen ist.
@MainActor
public final class NavigationAwaiter: NSObject {
    private let timeoutSeconds: TimeInterval

    public init(timeoutSeconds: TimeInterval = 25) {
        self.timeoutSeconds = timeoutSeconds
    }

    public func load(_ url: URL, in webView: NavigationWebView) async throws {
        let targetHost = (url.host ?? "").lowercased()
        let targetPath = NavigationTargetMatching.normalizedPath(url.path)

        if NavigationTargetMatching.isOnTarget(webView: webView, host: targetHost, path: targetPath),
           !webView.isLoading {
            return
        }

        webView.load(URLRequest(url: url))

        try await NavigationSettleLoop.wait(
            webView: webView,
            targetHost: targetHost,
            targetPath: targetPath,
            deadline: Date().addingTimeInterval(timeoutSeconds),
            timeoutURL: url
        )
    }
}
