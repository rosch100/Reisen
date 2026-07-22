import Foundation
import WebKit

/// Minimales Interface, das `NavigationAwaiter` für Tests benötigt.
/// So kann `load(...)` ohne echtes `WKWebView` ausgeführt werden.
///
/// Main-Actor-isoliert, damit die `WKWebView`-Conformance nicht in `@MainActor`
/// Code „crosses“ und auf Swift 6.2+ sonst zu `[ConformanceIsolation]` Fehlern führt.
@MainActor
public protocol NavigationWebView: AnyObject {
    var url: URL? { get }
    var isLoading: Bool { get }
    func load(_ request: URLRequest) -> WKNavigation?
}

extension WKWebView: NavigationWebView {
    // `WKWebView` liefert `url`, `isLoading` und `load(_:)` bereits.
}

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
        let targetPath = normalizedPath(url.path)

        if isOnTarget(webView: webView, host: targetHost, path: targetPath), !webView.isLoading {
            return
        }

        webView.load(URLRequest(url: url))

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        try await waitForNavigationToSettle(
            webView: webView,
            targetHost: targetHost,
            targetPath: targetPath,
            deadline: deadline,
            timeoutURL: url
        )
    }

    private func waitForNavigationToSettle(
        webView: NavigationWebView,
        targetHost: String,
        targetPath: String,
        deadline: Date,
        timeoutURL: URL
    ) async throws {
        var sawLoading = webView.isLoading

        while Date() < deadline {
            if try await navigationIteration(
                webView: webView,
                targetHost: targetHost,
                targetPath: targetPath,
                sawLoading: &sawLoading
            ) {
                return
            }
        }

        throw navigationTimeoutError(timeoutURL: timeoutURL)
    }

    private func navigationIteration(
        webView: NavigationWebView,
        targetHost: String,
        targetPath: String,
        sawLoading: inout Bool
    ) async throws -> Bool {
        if webView.isLoading {
            sawLoading = true
        }

        if shouldHandleSPAFollowup(webView: webView, targetHost: targetHost, targetPath: targetPath, sawLoading: sawLoading) {
            // SPA-Nachladen kurz abwarten.
            try await Task.sleep(nanoseconds: 350_000_000)
            if !webView.isLoading {
                return true
            }
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        return false
    }

    private func navigationTimeoutError(timeoutURL: URL) -> NSError {
        NSError(
            domain: "NavigationAwaiter",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Navigation-Timeout für \(timeoutURL.absoluteString)",
            ]
        )
    }

    private func shouldHandleSPAFollowup(
        webView: NavigationWebView,
        targetHost: String,
        targetPath: String,
        sawLoading: Bool
    ) -> Bool {
        isOnTarget(webView: webView, host: targetHost, path: targetPath)
            && !webView.isLoading
            && (sawLoading || webView.url != nil)
    }

    private func isOnTarget(webView: NavigationWebView, host: String, path: String) -> Bool {
        guard let current = webView.url else { return false }
        let currentHost = (current.host ?? "").lowercased()
        guard hostsMatch(currentHost, host) else { return false }
        return pathMatches(currentPath: normalizedPath(current.path), targetPath: path)
    }

    private func hostsMatch(_ a: String, _ b: String) -> Bool {
        let left = a.replacingOccurrences(of: "www.", with: "")
        let right = b.replacingOccurrences(of: "www.", with: "")
        return left == right
            || left.hasSuffix(".\(right)")
            || right.hasSuffix(".\(left)")
    }

    private func pathMatches(currentPath: String, targetPath: String) -> Bool {
        NavigationPathMatching.pathsMatch(currentPath: currentPath, targetPath: targetPath)
    }

    private func normalizedPath(_ path: String) -> String {
        if path.count > 1, path.hasSuffix("/") {
            return String(path.dropLast())
        }
        return path.isEmpty ? "/" : path
    }
}
