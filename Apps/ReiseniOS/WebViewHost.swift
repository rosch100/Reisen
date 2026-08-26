import SwiftUI
import SwiftData
import WebKit
import UIKit
import ObjectiveC

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
    @Binding var webView: WKWebView?
    let onDidFinish: (WKWebView) -> Void

    var body: some View {
        ProviderSessionWebView(
            loginURL: loginURL,
            webView: $webView,
            onDidFinish: onDidFinish
        )
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .clipped()
    }
}

struct ProviderSessionWebView: UIViewRepresentable {
    let loginURL: URL?
    @Binding var webView: WKWebView?
    let onDidFinish: (WKWebView) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDidFinish: onDidFinish)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: WebViewHostUIView, context: Context) -> CGSize? {
        WebViewHostFit.proposedSize(width: proposal.width, height: proposal.height)
    }

    func makeUIView(context: Context) -> WebViewHostUIView {
        let host = WebViewHostUIView()
        let view = makeWebView(context: context)
        host.embed(view)
        context.coordinator.loadedLoginURL = loginURL
        DispatchQueue.main.async {
            webView = view
        }
        if let loginURL { view.load(URLRequest(url: loginURL)) }
        return host
    }

    func updateUIView(_ uiView: WebViewHostUIView, context: Context) {
        guard let loginURL else { return }
        if context.coordinator.loadedLoginURL != loginURL {
            context.coordinator.loadedLoginURL = loginURL
            uiView.webView?.load(URLRequest(url: loginURL))
        }
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

        let view = InteractiveWKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
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
        WKWebViewInputAccessory.hide(on: view)
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

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let onDidFinish: (WKWebView) -> Void
        var loadedLoginURL: URL?

        init(onDidFinish: @escaping (WKWebView) -> Void) {
            self.onDidFinish = onDidFinish
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            applyAssistance(in: webView)
            onDidFinish(webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
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
            decisionHandler(.allow, preferences)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            onDidFinish(webView)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        private func applyAssistance(in webView: WKWebView) {
            WKWebViewInputAccessory.hide(on: webView)
            guard let absolute = webView.url?.absoluteString, !absolute.isEmpty else { return }
            if AuthPageURLHeuristic.shouldApplyOneTimeCodeAutofill(absolute) {
                OneTimeCodeAutofill.apply(in: webView, relaxSplitFieldMaxLength: true)
            }
            if AuthPageURLHeuristic.looksLikeLoginPage(absolute) {
                webView.evaluateJavaScript(LoginFieldHintsScript.build()) { _, _ in }
            }
        }
    }
}

/// Clippt den WebView an die SwiftUI-Zuteilung und hebt den Inhalt über die Tastatur.
final class WebViewHostUIView: UIView {
    private(set) var webView: InteractiveWKWebView?
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
        WKWebViewInputAccessory.hide(on: webView)
        invalidateIntrinsicContentSize()
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

    override var inputAccessoryView: UIView? { nil }

    override var inputAssistantItem: UITextInputAssistantItem {
        let item = super.inputAssistantItem
        item.leadingBarButtonGroups = []
        item.trailingBarButtonGroups = []
        return item
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)) || action == #selector(copy(_:)) || action == #selector(selectAll(_:)) {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        WKWebViewInputAccessory.hide(on: self)
    }
}

/// WKContentView (nicht WKWebView) ist First Responder — Accessory nur dort abschaltbar.
enum WKWebViewInputAccessory {
    static func hide(on webView: WKWebView) {
        let assistant = webView.inputAssistantItem
        assistant.leadingBarButtonGroups = []
        assistant.trailingBarButtonGroups = []
        hideInSubtree(webView)
    }

    private static func hideInSubtree(_ view: UIView) {
        let name = NSStringFromClass(type(of: view))
        if name.contains("WKContent"), !name.contains("ReisenNoInputAccessory") {
            installNoAccessorySubclass(on: view)
        }
        for subview in view.subviews {
            hideInSubtree(subview)
        }
    }

    private static func installNoAccessorySubclass(on view: UIView) {
        let original = type(of: view)
        let subclassName = "ReisenNoInputAccessory_\(NSStringFromClass(original))"
        let subclass: AnyClass
        if let existing = NSClassFromString(subclassName) {
            subclass = existing
        } else {
            guard let allocated = objc_allocateClassPair(original, subclassName, 0) else { return }
            let impl: @convention(block) (AnyObject) -> UIView? = { _ in nil }
            class_addMethod(
                allocated,
                #selector(getter: UIResponder.inputAccessoryView),
                imp_implementationWithBlock(impl),
                "@@:"
            )
            objc_registerClassPair(allocated)
            subclass = allocated
        }
        object_setClass(view, subclass)
    }
}
