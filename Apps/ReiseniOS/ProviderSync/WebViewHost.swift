import SwiftUI
import SwiftData
import WebKit
import UIKit

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData
import ReisenProviders

/// iOS-Provider-Browser: immer mobile Website, nie Desktop-Layout wie in der Mac-App.
enum ProviderWebViewMobileMode {
    static func apply(to preferences: WKWebpagePreferences) {
        preferences.allowsContentJavaScript = true
        preferences.preferredContentMode = .mobile
    }

    /// iPhone-Safari-UA auch auf iPad, sonst liefern Provider oft die Desktop-Seite.
    static var safariMobileUserAgent: String {
        let os = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        let version = UIDevice.current.systemVersion
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(os) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(version) Mobile/15E148 Safari/604.1"
    }
}

/// SwiftUI soll die WebView-Fläche setzen, nicht die intrinsische Seitenbreite von WKWebView.
enum WebViewHostFit {
    static func proposedSize(width: CGFloat?, height: CGFloat?) -> CGSize? {
        guard let width, let height,
              width.isFinite, height.isFinite,
              width > 0, height > 0 else { return nil }
        return CGSize(width: width, height: height)
    }
}

struct WebViewHost: View {
    let loginURL: URL?
    let providerID: ProviderID
    var diagnosticContext: DiagnosticContext?
    @Binding var webView: WKWebView?
    var allowsEmbed: Bool
    let onDidFinish: (WKWebView) -> Void
    var onCapturedCredentials: ((ProviderCredentials) -> Void)?
    var onNavigationBlocked: (() -> Void)?

    var body: some View {
        ProviderSessionWebView(
            loginURL: loginURL,
            providerID: providerID,
            diagnosticContext: diagnosticContext,
            webView: $webView,
            allowsEmbed: allowsEmbed,
            onDidFinish: onDidFinish,
            onCapturedCredentials: onCapturedCredentials,
            onNavigationBlocked: onNavigationBlocked
        )
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .clipped()
    }
}

struct ProviderSessionWebView: UIViewRepresentable {
    let loginURL: URL?
    let providerID: ProviderID
    var diagnosticContext: DiagnosticContext?
    @Binding var webView: WKWebView?
    var allowsEmbed: Bool
    let onDidFinish: (WKWebView) -> Void
    var onCapturedCredentials: ((ProviderCredentials) -> Void)?
    var onNavigationBlocked: (() -> Void)?
    @Environment(\.providerSessionHub) private var sessionHub

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onDidFinish: onDidFinish,
            onCapturedCredentials: onCapturedCredentials,
            onNavigationBlocked: onNavigationBlocked,
            diagnosticContext: diagnosticContext
        )
    }

    static func dismantleUIView(_ uiView: WebViewHostUIView, coordinator: Coordinator) {
        coordinator.tearDown(from: uiView.webView)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: WebViewHostUIView, context: Context) -> CGSize? {
        WebViewHostFit.proposedSize(width: proposal.width, height: proposal.height)
    }

    func makeUIView(context: Context) -> WebViewHostUIView {
        let host = WebViewHostUIView()
        let view = resolveWebView(context: context)
        if allowsEmbed {
            attachCoordinator(view, context: context)
            host.embed(view)
        }
        context.coordinator.loadedLoginURL = loginURL
        DispatchQueue.main.async {
            webView = view
        }
        if allowsEmbed, let loginURL { view.load(URLRequest(url: loginURL)) }
        return host
    }

    func updateUIView(_ uiView: WebViewHostUIView, context: Context) {
        let view = resolveWebView(context: context)
        context.coordinator.diagnosticContext = diagnosticContext
        if allowsEmbed {
            attachCoordinator(view, context: context)
            if uiView.webView !== view || view.superview !== uiView {
                uiView.embed(view)
                context.coordinator.recordNavigationEvent(
                    "webview_reparented",
                    result: .succeeded,
                    webView: view
                )
            }
        }
        if webView !== view {
            DispatchQueue.main.async {
                webView = view
            }
        }
        guard allowsEmbed, let loginURL else { return }
        if context.coordinator.loadedLoginURL != loginURL {
            context.coordinator.loadedLoginURL = loginURL
            view.load(URLRequest(url: loginURL))
        }
    }

    private func resolveWebView(context: Context) -> InteractiveWKWebView {
        if let existing = webView as? InteractiveWKWebView {
            return existing
        }
        if let hubView = sessionHub?.webView(for: providerID) as? InteractiveWKWebView {
            return hubView
        }
        return makeWebView(context: context)
    }

    private func attachCoordinator(_ view: InteractiveWKWebView, context: Context) {
        let ucc = view.configuration.userContentController
        ucc.removeScriptMessageHandler(forName: LoginFormCapture.messageHandlerName)
        ucc.add(context.coordinator, name: LoginFormCapture.messageHandlerName)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
    }

    private func makeWebView(context: Context) -> InteractiveWKWebView {
        let preferences = WKWebpagePreferences()
        ProviderWebViewMobileMode.apply(to: preferences)

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences = preferences
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.userContentController.addUserScript(
            WKUserScript(source: Self.viewportScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        configuration.userContentController.add(context.coordinator, name: LoginFormCapture.messageHandlerName)

        let view = InteractiveWKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        context.coordinator.recordNavigationEvent(
            "webview_created",
            result: .succeeded,
            webView: view
        )
        view.customUserAgent = ProviderWebViewMobileMode.safariMobileUserAgent
        view.allowsBackForwardNavigationGestures = true
        view.scrollView.keyboardDismissMode = .interactive
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.scrollView.alwaysBounceVertical = true
        view.isOpaque = true
        view.backgroundColor = .systemBackground
        view.scrollView.backgroundColor = .systemBackground
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    private static let viewportScript = """
        (function() {
          function apply() {
            var head = document.head || document.getElementsByTagName('head')[0];
            if (!head) return;
            var meta = document.querySelector('meta[name="viewport"]');
            var content = 'width=device-width, initial-scale=1, maximum-scale=1, viewport-fit=cover';
            if (!meta) {
              meta = document.createElement('meta');
              meta.name = 'viewport';
              meta.content = content;
              head.appendChild(meta);
              return;
            }
            meta.setAttribute('content', content);
          }
          apply();
        })();
        """

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let onDidFinish: (WKWebView) -> Void
        let onCapturedCredentials: ((ProviderCredentials) -> Void)?
        let onNavigationBlocked: (() -> Void)?
        var diagnosticContext: DiagnosticContext?
        var loadedLoginURL: URL?
        private weak var authPopupWebView: WKWebView?
        private weak var authPopupParent: WKWebView?
        private var authPopupSawIdentityProvider = false

        init(
            onDidFinish: @escaping (WKWebView) -> Void,
            onCapturedCredentials: ((ProviderCredentials) -> Void)?,
            onNavigationBlocked: (() -> Void)?,
            diagnosticContext: DiagnosticContext?
        ) {
            self.onDidFinish = onDidFinish
            self.onCapturedCredentials = onCapturedCredentials
            self.onNavigationBlocked = onNavigationBlocked
            self.diagnosticContext = diagnosticContext
        }

        func tearDown(from webView: WKWebView?) {
            dismissAuthPopup(reloadParent: false)
            webView?.configuration.userContentController.removeScriptMessageHandler(
                forName: LoginFormCapture.messageHandlerName
            )
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            LoginFormCapture.handleScriptMessage(message, webView: message.webView) { credentials in
                onCapturedCredentials?(credentials)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            recordNavigationEvent("did_finish", result: .succeeded, webView: webView)
            if webView === authPopupWebView {
                handleAuthPopupNavigation(webView, allowDismiss: true)
                return
            }
            applyAssistance(in: webView)
            onDidFinish(webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            recordNavigationEvent("did_commit", result: .started, webView: webView)
            if webView === authPopupWebView {
                handleAuthPopupNavigation(webView, allowDismiss: false)
                return
            }
            applyAssistance(in: webView)
            onDidFinish(webView)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            preferences: WKWebpagePreferences,
            decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
        ) {
            ProviderWebViewMobileMode.apply(to: preferences)
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? false
            if let url = navigationAction.request.url,
               !allowsNavigation(to: url, isMainFrame: isMainFrame) {
                recordNavigationEvent(
                    "navigation_blocked",
                    result: .skipped,
                    webView: webView,
                    reason: "navigation_policy"
                )
                decisionHandler(.cancel, preferences)
                return
            }
            decisionHandler(.allow, preferences)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            recordNavigationEvent(
                "did_fail_provisional",
                result: .failed,
                webView: webView,
                error: error
            )
            onDidFinish(webView)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            recordNavigationEvent(
                "did_fail",
                result: .failed,
                webView: webView,
                error: error
            )
        }

        func recordNavigationEvent(
            _ event: String,
            result: DiagnosticResult,
            webView: WKWebView,
            error: Error? = nil,
            reason: String? = nil
        ) {
            guard let diagnosticContext else { return }
            Task {
                await DiagnosticLogger.shared.record(
                    DiagnosticEvent(
                        context: diagnosticContext,
                        component: "ProviderSessionWebView",
                        phase: "navigation",
                        event: event,
                        result: result,
                        url: webView.url.flatMap { DiagnosticRedactor.urlMetadata(for: $0) },
                        errorType: error.map { String(reflecting: type(of: $0)) },
                        reason: reason ?? error.map { DiagnosticRedactor.redact($0.localizedDescription) }
                    )
                )
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard navigationAction.targetFrame == nil else { return nil }
            switch ProviderAuthPopupPolicy.createAction(
                requestURL: navigationAction.request.url,
                allows: { ProviderWebViewNavigationPolicy.allows($0, isMainFrame: true) }
            ) {
            case .block:
                recordNavigationEvent(
                    "popup_blocked",
                    result: .skipped,
                    webView: webView,
                    reason: navigationAction.request.url == nil
                        ? "missing_request_url"
                        : "navigation_policy"
                )
                if navigationAction.request.url != nil {
                    onNavigationBlocked?()
                }
                return nil
            case .presentChild:
                guard let host = webView.superview as? WebViewHostUIView else {
                    recordNavigationEvent(
                        "popup_present_failed",
                        result: .failed,
                        webView: webView,
                        reason: "missing_host"
                    )
                    return nil
                }
                dismissAuthPopup(reloadParent: false)
                let popup = InteractiveWKWebView(frame: .zero, configuration: configuration)
                popup.navigationDelegate = self
                popup.uiDelegate = self
                popup.customUserAgent = webView.customUserAgent
                authPopupWebView = popup
                authPopupParent = webView
                authPopupSawIdentityProvider = false
                if let requestURL = navigationAction.request.url {
                    authPopupSawIdentityProvider = ProviderAuthPopupPolicy.noteIdentityProviderSighting(
                        currentURL: requestURL,
                        alreadySawIdentityProvider: false
                    )
                }
                host.presentAuthPopup(popup)
                recordNavigationEvent(
                    "popup_presented",
                    result: .succeeded,
                    webView: webView,
                    reason: "child_webview"
                )
                return popup
            }
        }

        func webViewDidClose(_ webView: WKWebView) {
            guard webView === authPopupWebView else { return }
            recordNavigationEvent(
                "popup_closed",
                result: .succeeded,
                webView: webView,
                reason: "webview_did_close"
            )
            dismissAuthPopup(reloadParent: true)
        }

        private func handleAuthPopupNavigation(_ webView: WKWebView, allowDismiss: Bool) {
            guard let url = webView.url else { return }
            authPopupSawIdentityProvider = ProviderAuthPopupPolicy.noteIdentityProviderSighting(
                currentURL: url,
                alreadySawIdentityProvider: authPopupSawIdentityProvider
            )
            guard allowDismiss else { return }
            let parentURL = authPopupParent?.url ?? loadedLoginURL
            guard ProviderAuthPopupPolicy.shouldDismissChildAfterLoad(
                childURL: url,
                parentURL: parentURL,
                sawIdentityProvider: authPopupSawIdentityProvider
            ) else { return }
            recordNavigationEvent(
                "popup_completed",
                result: .succeeded,
                webView: webView,
                reason: "returned_to_provider_site"
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self, weak webView] in
                guard let self, let webView, webView === self.authPopupWebView else { return }
                self.dismissAuthPopup(reloadParent: true)
            }
        }

        private func dismissAuthPopup(reloadParent: Bool) {
            let parent = authPopupParent
            if let host = parent?.superview as? WebViewHostUIView {
                host.dismissAuthPopup()
            } else {
                authPopupWebView?.removeFromSuperview()
            }
            authPopupWebView?.navigationDelegate = nil
            authPopupWebView?.uiDelegate = nil
            authPopupWebView = nil
            authPopupParent = nil
            authPopupSawIdentityProvider = false
            guard reloadParent, let parent else { return }
            if parent.url != nil {
                parent.reload()
            } else if let loadedLoginURL {
                parent.load(URLRequest(url: loadedLoginURL))
            }
        }

        private func allowsNavigation(to url: URL, isMainFrame: Bool) -> Bool {
            guard ProviderWebViewNavigationPolicy.allows(url, isMainFrame: isMainFrame) else {
                onNavigationBlocked?()
                return false
            }
            return true
        }

        private func applyAssistance(in webView: WKWebView) {
            guard let absolute = webView.url?.absoluteString, !absolute.isEmpty else { return }
            if AuthPageURLHeuristic.shouldApplyOneTimeCodeAutofill(absolute) {
                OneTimeCodeAutofill.apply(in: webView, relaxSplitFieldMaxLength: true)
            }
            ProviderLoginAssistance.installOnLoginPage(
                in: webView,
                diagnosticContext: diagnosticContext
            )
        }
    }
}

/// Clippt den WebView an die SwiftUI-Zuteilung und hebt den Inhalt über die Tastatur.
final class WebViewHostUIView: UIView {
    private(set) var webView: InteractiveWKWebView?
    private(set) var authPopupWebView: WKWebView?
    private var keyboardObservers: [NSObjectProtocol] = []

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundColor = .systemBackground
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopListeningToKeyboard()
        } else if keyboardObservers.isEmpty {
            listenToKeyboard()
        }
    }

    func embed(_ webView: InteractiveWKWebView) {
        if self.webView === webView, webView.superview === self { return }
        self.webView?.removeFromSuperview()
        self.webView = webView
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.clipsToBounds = true
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        invalidateIntrinsicContentSize()
    }

    func presentAuthPopup(_ popup: WKWebView) {
        dismissAuthPopup()
        authPopupWebView = popup
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.clipsToBounds = true
        addSubview(popup)
        NSLayoutConstraint.activate([
            popup.topAnchor.constraint(equalTo: topAnchor),
            popup.bottomAnchor.constraint(equalTo: bottomAnchor),
            popup.leadingAnchor.constraint(equalTo: leadingAnchor),
            popup.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        invalidateIntrinsicContentSize()
    }

    func dismissAuthPopup() {
        authPopupWebView?.removeFromSuperview()
        authPopupWebView = nil
    }

    private func listenToKeyboard() {
        let center = NotificationCenter.default
        keyboardObservers.append(center.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            Task { @MainActor [weak self] in
                self?.applyKeyboardFrame(frame)
            }
        })
        keyboardObservers.append(center.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyKeyboardFrame(nil)
            }
        })
    }

    private func stopListeningToKeyboard() {
        for observer in keyboardObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        keyboardObservers.removeAll()
    }

    private func applyKeyboardFrame(_ endFrame: CGRect?) {
        guard let webView else { return }
        guard let endFrame else {
            webView.scrollView.contentInset.bottom = 0
            webView.scrollView.verticalScrollIndicatorInsets.bottom = 0
            return
        }
        let keyboardInSelf = convert(endFrame, from: nil)
        let overlap = bounds.intersection(keyboardInSelf).height
        let inset = overlap > 1 ? overlap : 0
        webView.scrollView.contentInset.bottom = inset
        webView.scrollView.verticalScrollIndicatorInsets.bottom = inset
        webView.scrollView.horizontalScrollIndicatorInsets.bottom = 0
    }
}

final class InteractiveWKWebView: WKWebView {
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override var canBecomeFirstResponder: Bool { true }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)) || action == #selector(copy(_:)) || action == #selector(selectAll(_:)) {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }
}
