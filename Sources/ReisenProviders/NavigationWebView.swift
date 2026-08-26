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
