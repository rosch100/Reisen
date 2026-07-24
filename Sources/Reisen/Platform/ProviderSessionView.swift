import SwiftUI
import WebKit
import AppKit
import ReisenProviders

enum ProviderSessionStatus: Equatable {
    case needsLogin
    case sessionReady
}

/// Vollflächiger Provider-Browser für alle Provider (Check24, Opodo, Booking.com, …).
/// Kein ScrollView/Form-Container — sonst ist der Login auf macOS oft nicht bedienbar.
struct ProviderSessionView: View {
    let loginURL: URL?
    @Binding var sessionStatus: ProviderSessionStatus
    @Binding var lastURLString: String?
    @Binding var webView: WKWebView?

    let autofillCredentials: ProviderCredentials?
    let rememberTrustedDeviceAutomatically: Bool

    init(
        loginURL: URL?,
        sessionStatus: Binding<ProviderSessionStatus>,
        lastURLString: Binding<String?>,
        webView: Binding<WKWebView?>,
        autofillCredentials: ProviderCredentials? = nil,
        rememberTrustedDeviceAutomatically: Bool = true
    ) {
        self.loginURL = loginURL
        self._sessionStatus = sessionStatus
        self._lastURLString = lastURLString
        self._webView = webView
        self.autofillCredentials = autofillCredentials
        self.rememberTrustedDeviceAutomatically = rememberTrustedDeviceAutomatically
    }

    var body: some View {
        ProviderWebView(
            loginURL: loginURL,
            sessionStatus: $sessionStatus,
            lastURLString: $lastURLString,
            webViewRef: $webView,
            autofillCredentials: autofillCredentials,
            rememberTrustedDeviceAutomatically: rememberTrustedDeviceAutomatically
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// WKWebView mit korrekter First-Responder- und Edit-Menü-Unterstützung (⌘C/⌘V/Tipperei).
final class FocusableWKWebView: WKWebView {
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Standard-Edit-Shortcuts an das WebView weiterreichen, bevor SwiftUI sie schluckt.
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers?.lowercased() {
            switch chars {
            case "c":
                NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
                return true
            case "v":
                NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
                return true
            case "x":
                NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
                return true
            case "a":
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
                return true
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// Clippt den WebView fest an die SwiftUI-Zuteilung (verhindert Titlebar-Bleed).
private final class WebViewHostView: NSView {
    private(set) var webView: FocusableWKWebView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func embed(_ webView: FocusableWKWebView) {
        // Wenn dieselbe Instanz noch unser Subview ist: fertig.
        // Wenn sie nur als Property hängt, aber inzwischen woanders embedded wurde
        // (z. B. Hintergrund-Bootstrap 1×1-Host): neu einbinden.
        if self.webView === webView, webView.superview === self { return }

        if self.webView !== webView {
            self.webView?.removeFromSuperview()
        } else if webView.superview !== self {
            webView.removeFromSuperview()
        }
        self.webView = webView
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.setContentHuggingPriority(.defaultLow, for: .vertical)
        webView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        webView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        webView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        webView.clipsToBounds = true
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    func detachWebView() -> FocusableWKWebView? {
        let existing = webView
        if existing?.superview === self {
            existing?.removeFromSuperview()
        }
        webView = nil
        return existing
    }

    /// Nur die Host-Referenz lösen — WebView bleibt wo sie gerade hängt.
    func releaseWebViewReference() {
        webView = nil
    }
}

private struct ProviderWebView: NSViewRepresentable {
    let loginURL: URL?
    @Binding var sessionStatus: ProviderSessionStatus
    @Binding var lastURLString: String?
    @Binding var webViewRef: WKWebView?

    let autofillCredentials: ProviderCredentials?
    let rememberTrustedDeviceAutomatically: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            sessionStatus: $sessionStatus,
            lastURLString: $lastURLString,
            autofillCredentials: autofillCredentials,
            rememberTrustedDeviceAutomatically: rememberTrustedDeviceAutomatically
        )
    }

    func makeNSView(context: Context) -> WebViewHostView {
        let host = WebViewHostView(frame: .zero)
        let webView = resolveWebView(context: context)
        host.embed(webView)
        context.coordinator.observeWindowActivation(for: webView)

        DispatchQueue.main.async {
            webViewRef = webView
            webView.window?.makeFirstResponder(webView)
            if let loginURL {
                let current = webView.url?.absoluteString
                context.coordinator.loadedLoginURL = loginURL
                // Hub-WebView kann noch eine alte URL haben (z. B. Opodo /travel/secure/).
                if current != loginURL.absoluteString {
                    // #region agent log
                    AgentDebugLog.write(
                        hypothesisId: "Z",
                        location: "ProviderSessionView.swift:makeNSView",
                        message: "load loginURL",
                        data: [
                            "loginURL": loginURL.absoluteString,
                            "previousURL": current ?? "nil",
                        ]
                    )
                    // #endregion
                    webView.load(URLRequest(url: loginURL))
                }
            }
        }

        return host
    }

    func updateNSView(_ nsView: WebViewHostView, context: Context) {
        let credentialsChanged = context.coordinator.setAutofillCredentials(autofillCredentials)
        context.coordinator.update(
            sessionStatus: $sessionStatus,
            lastURLString: $lastURLString,
            rememberTrustedDeviceAutomatically: rememberTrustedDeviceAutomatically
        )

        let webView = resolveWebView(context: context)
        // Auch neu einbinden, wenn die Property noch gesetzt ist, der WebView aber
        // inzwischen in einem anderen Host (Hintergrund-Bootstrap) hängt.
        if nsView.webView !== webView || webView.superview !== nsView {
            nsView.embed(webView)
            context.coordinator.observeWindowActivation(for: webView)
        }

        if webViewRef !== webView {
            DispatchQueue.main.async {
                webViewRef = webView
            }
        }

        if let loginURL, context.coordinator.loadedLoginURL != loginURL {
            context.coordinator.loadedLoginURL = loginURL
            webView.load(URLRequest(url: loginURL))
        } else if credentialsChanged {
            // #region agent log
            AgentDebugLog.write(
                hypothesisId: "B",
                location: "ProviderSessionView.swift:updateNSView",
                message: "credentialsChanged → scheduleLoginAssistance",
                data: [
                    "hasCredentials": autofillCredentials != nil,
                    "url": webView.url?.absoluteString ?? "nil",
                ]
            )
            // #endregion
            context.coordinator.scheduleLoginAssistance(in: webView)
        }
    }

    static func dismantleNSView(_ nsView: WebViewHostView, coordinator: Coordinator) {
        // Wenn die WebView bereits in einen anderen Host übernommen wurde
        // (sichtbarer SyncView vs. 1×1-Bootstrap), Delegates dort nicht zerstören.
        if let webView = nsView.webView, webView.superview === nsView {
            let ucc = webView.configuration.userContentController
            ucc.removeScriptMessageHandler(forName: LoginFieldHints.messageHandlerName)
            ucc.removeScriptMessageHandler(forName: LoginSubmitDebugProbe.messageHandlerName)
            webView.navigationDelegate = nil
            _ = nsView.detachWebView()
        } else {
            nsView.releaseWebViewReference()
        }
        coordinator.tearDown()
    }

    private func resolveWebView(context: Context) -> FocusableWKWebView {
        if let existing = webViewRef as? FocusableWKWebView {
            attachCoordinator(existing, context: context)
            return existing
        }
        return makeFreshWebView(context: context)
    }

    private func makeFreshWebView(context: Context) -> FocusableWKWebView {
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences = preferences
        if #available(macOS 15.0, *) {
            config.preferences.isElementFullscreenEnabled = true
        }
        config.userContentController.add(context.coordinator, name: LoginFieldHints.messageHandlerName)
        LoginSubmitDebugProbe.addMessageHandler(to: config.userContentController, handler: context.coordinator)
        LoginSubmitDebugProbe.addUserScript(to: config.userContentController)

        let webView = FocusableWKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        // Safari-UA: manche Provider (Opodo) unterdrücken Auth-XHR in Default-WKWebView-UA.
        webView.customUserAgent = Self.safariUserAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        return webView
    }

    /// Angeglichene Safari-Desktop-UA (ohne App-Namen im Token).
    private static let safariUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15"

    private func attachCoordinator(_ webView: FocusableWKWebView, context: Context) {
        let ucc = webView.configuration.userContentController
        ucc.removeScriptMessageHandler(forName: LoginFieldHints.messageHandlerName)
        ucc.add(context.coordinator, name: LoginFieldHints.messageHandlerName)
        LoginSubmitDebugProbe.addMessageHandler(to: ucc, handler: context.coordinator)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        if webView.customUserAgent == nil || webView.customUserAgent?.isEmpty == true {
            webView.customUserAgent = Self.safariUserAgent
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        private var sessionStatus: Binding<ProviderSessionStatus>
        private var lastURLString: Binding<String?>
        private var autofillCredentials: ProviderCredentials?
        private var rememberTrustedDeviceAutomatically: Bool
        private var becomeKeyObserver: NSObjectProtocol?
        private weak var trackedWebView: WKWebView?
        private var loginAssistanceWorkItem: DispatchWorkItem?
        private var sessionProbeWorkItem: DispatchWorkItem?
        var loadedLoginURL: URL?
        // #region agent log
        private var assistanceScheduleCount = 0
        private var assistanceApplyCount = 0
        private var fieldsChangedNotifyCount = 0
        private var autofillApplyCount = 0
        // #endregion
        /// Während „Anmelden…“ (Post-Submit) keine DOM-Hilfe mehr.
        private var loginAssistanceSuspended = false

        init(
            sessionStatus: Binding<ProviderSessionStatus>,
            lastURLString: Binding<String?>,
            autofillCredentials: ProviderCredentials?,
            rememberTrustedDeviceAutomatically: Bool
        ) {
            self.sessionStatus = sessionStatus
            self.lastURLString = lastURLString
            self.autofillCredentials = autofillCredentials
            self.rememberTrustedDeviceAutomatically = rememberTrustedDeviceAutomatically
        }

        func update(
            sessionStatus: Binding<ProviderSessionStatus>,
            lastURLString: Binding<String?>,
            rememberTrustedDeviceAutomatically: Bool
        ) {
            self.sessionStatus = sessionStatus
            self.lastURLString = lastURLString
            self.rememberTrustedDeviceAutomatically = rememberTrustedDeviceAutomatically
        }

        @discardableResult
        func setAutofillCredentials(_ credentials: ProviderCredentials?) -> Bool {
            let changed = autofillCredentials != credentials
            autofillCredentials = credentials
            return changed
        }

        func observeWindowActivation(for webView: WKWebView) {
            trackedWebView = webView
            if let becomeKeyObserver {
                NotificationCenter.default.removeObserver(becomeKeyObserver)
            }
            becomeKeyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let window = notification.object as? NSWindow
                Task { @MainActor in
                    guard let self,
                          let window,
                          let tracked = self.trackedWebView,
                          tracked.window === window else { return }
                    window.makeFirstResponder(tracked)
                }
            }
        }

        func tearDown() {
            loginAssistanceWorkItem?.cancel()
            loginAssistanceWorkItem = nil
            sessionProbeWorkItem?.cancel()
            sessionProbeWorkItem = nil
            if let becomeKeyObserver {
                NotificationCenter.default.removeObserver(becomeKeyObserver)
            }
            becomeKeyObserver = nil
            trackedWebView = nil
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == LoginSubmitDebugProbe.messageHandlerName {
                handleLoginDebugMessage(message)
                return
            }
            guard message.name == LoginFieldHints.messageHandlerName else { return }
            guard let webView = trackedWebView ?? message.webView else { return }
            Task { @MainActor in
                // #region agent log
                fieldsChangedNotifyCount += 1
                AgentDebugLog.write(
                    hypothesisId: "K",
                    location: "ProviderSessionView.swift:userContentController",
                    message: "LoginFieldHints fieldsChanged notify",
                    data: [
                        "notifyCount": fieldsChangedNotifyCount,
                        "url": webView.url?.absoluteString ?? "nil",
                        "suspended": loginAssistanceSuspended,
                        "hasCredentials": autofillCredentials != nil,
                    ]
                )
                // #endregion
                guard !loginAssistanceSuspended else { return }
                scheduleLoginAssistance(in: webView)
            }
        }

        private func handleLoginDebugMessage(_ message: WKScriptMessage) {
            let body = message.body as? [String: Any]
                ?? (message.body as? NSDictionary).map { ns -> [String: Any] in
                    var mapped: [String: Any] = [:]
                    for (key, value) in ns {
                        if let key = key as? String { mapped[key] = value }
                    }
                    return mapped
                }
                ?? [:]
            let type = body["type"] as? String ?? ""
            var data: [String: Any] = [:]
            for (key, value) in body {
                if value is NSNull { continue }
                if value is String || value is NSNumber || value is Bool {
                    data[key] = value
                } else {
                    data[key] = String(describing: value)
                }
            }
            // #region agent log
            AgentDebugLog.write(
                hypothesisId: type == "busy" ? "K,N" : "L,M",
                location: "ProviderSessionView.swift:loginDebug",
                message: "login submit probe",
                data: data
            )
            // #endregion
            if type == "busy", body["busy"] as? Bool == true {
                Task { @MainActor in
                    self.suspendLoginAssistance()
                    if let webView = self.trackedWebView ?? message.webView {
                        self.probeLoginFieldsAtBusy(in: webView)
                    }
                }
            } else if type == "busy", body["busy"] as? Bool == false {
                Task { @MainActor in
                    if let webView = self.trackedWebView ?? message.webView {
                        self.scheduleOpodoSessionProbe(in: webView)
                    }
                }
            }
        }

        @MainActor
        private func probeLoginFieldsAtBusy(in webView: WKWebView) {
            let script = """
            (function() {
              function meta(el) {
                if (!el) return null;
                return {
                  type: (el.type || '').toLowerCase(),
                  name: el.name || '',
                  id: el.id || '',
                  autocomplete: el.getAttribute('autocomplete') || '',
                  len: (el.value || '').length,
                  visible: !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length)
                };
              }
              const all = Array.from(document.querySelectorAll('input'));
              const emails = all.filter(function(el) {
                const t = (el.type || '').toLowerCase();
                const hay = [el.name, el.id, el.placeholder, el.getAttribute('autocomplete')].join(' ').toLowerCase();
                return t === 'email' || /e-?mail|username|user/.test(hay);
              }).map(meta);
              const passes = all.filter(function(el) {
                return (el.type || '').toLowerCase() === 'password';
              }).map(meta);
              return {
                inputCount: all.length,
                visibleCount: all.filter(function(el) {
                  return el.offsetWidth || el.offsetHeight || el.getClientRects().length;
                }).length,
                emails: emails.slice(0, 5),
                passwords: passes.slice(0, 5),
                ua: navigator.userAgent.slice(0, 120)
              };
            })();
            """
            webView.evaluateJavaScript(script) { result, error in
                // #region agent log
                var data: [String: Any] = [:]
                if let error {
                    data["error"] = error.localizedDescription
                }
                if let dict = result as? [String: Any] {
                    for (key, value) in dict {
                        if value is String || value is NSNumber || value is Bool {
                            data[key] = value
                        } else {
                            data[key] = String(describing: value)
                        }
                    }
                }
                AgentDebugLog.write(
                    hypothesisId: "S,T",
                    location: "ProviderSessionView.swift:probeLoginFieldsAtBusy",
                    message: "field state at Anmelden busy",
                    data: data
                )
                // #endregion
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // #region agent log
            AgentDebugLog.write(
                hypothesisId: "M",
                location: "ProviderSessionView.swift:didFinish",
                message: "navigation didFinish",
                data: ["url": webView.url?.absoluteString ?? "nil"]
            )
            // #endregion
            updateSession(from: webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            // #region agent log
            AgentDebugLog.write(
                hypothesisId: "M",
                location: "ProviderSessionView.swift:didCommit",
                message: "navigation didCommit",
                data: ["url": webView.url?.absoluteString ?? "nil"]
            )
            // #endregion
            updateSession(from: webView)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            // #region agent log
            AgentDebugLog.write(
                hypothesisId: "L,M",
                location: "ProviderSessionView.swift:didFail",
                message: "navigation didFail",
                data: [
                    "url": webView.url?.absoluteString ?? "nil",
                    "error": error.localizedDescription,
                ]
            )
            // #endregion
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            // #region agent log
            AgentDebugLog.write(
                hypothesisId: "L,M",
                location: "ProviderSessionView.swift:didFailProvisional",
                message: "navigation didFailProvisional",
                data: [
                    "url": webView.url?.absoluteString ?? "nil",
                    "error": error.localizedDescription,
                ]
            )
            // #endregion
        }

        @MainActor
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
        ) {
            let url = navigationAction.request.url?.absoluteString ?? "nil"
            let isMain = navigationAction.targetFrame?.isMainFrame ?? false
            // #region agent log
            if url.lowercased().contains("opodo")
                || url.lowercased().contains("login")
                || url.lowercased().contains("auth")
                || url.lowercased().contains("google")
                || url.lowercased().contains("account") {
                AgentDebugLog.write(
                    hypothesisId: "M",
                    location: "ProviderSessionView.swift:decidePolicy",
                    message: "navigation action",
                    data: [
                        "url": String(url.prefix(300)),
                        "mainFrame": isMain,
                        "type": "\(navigationAction.navigationType.rawValue)",
                    ]
                )
            }
            // #endregion
            decisionHandler(.allow)
        }

        @MainActor
        func scheduleLoginAssistance(in webView: WKWebView) {
            loginAssistanceWorkItem?.cancel()
            // #region agent log
            assistanceScheduleCount += 1
            AgentDebugLog.write(
                hypothesisId: "A,E",
                location: "ProviderSessionView.swift:scheduleLoginAssistance",
                message: "scheduleLoginAssistance",
                data: [
                    "scheduleCount": assistanceScheduleCount,
                    "url": webView.url?.absoluteString ?? "nil",
                    "hasCredentials": autofillCredentials != nil,
                ]
            )
            // #endregion
            let work = DispatchWorkItem { [weak self, weak webView] in
                guard let self, let webView else { return }
                self.applyLoginAssistance(in: webView)
            }
            loginAssistanceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
        }

        @MainActor
        func suspendLoginAssistance() {
            loginAssistanceSuspended = true
            loginAssistanceWorkItem?.cancel()
            loginAssistanceWorkItem = nil
            // #region agent log
            AgentDebugLog.write(
                hypothesisId: "F,H",
                location: "ProviderSessionView.swift:suspendLoginAssistance",
                message: "login assistance suspended",
                data: [:]
            )
            // #endregion
        }

        @MainActor
        func applyLoginAssistance(in webView: WKWebView) {
            guard let url = webView.url else { return }
            let absolute = url.absoluteString.lowercased()
            let isLogin = AuthPageURLHeuristic.looksLikeLoginPage(absolute)
            // #region agent log
            assistanceApplyCount += 1
            AgentDebugLog.write(
                hypothesisId: "B,D,E",
                location: "ProviderSessionView.swift:applyLoginAssistance",
                message: "applyLoginAssistance",
                data: [
                    "applyCount": assistanceApplyCount,
                    "url": url.absoluteString,
                    "isLogin": isLogin,
                    "suspended": loginAssistanceSuspended,
                    "willRemember": rememberTrustedDeviceAutomatically && isLogin && !loginAssistanceSuspended,
                    "hasCredentials": autofillCredentials != nil,
                ]
            )
            // #endregion
            guard isLogin else {
                loginAssistanceSuspended = false
                return
            }
            guard !loginAssistanceSuspended else { return }

            // Hypothese F/H: Während Opodo „Anmelden…“ keine weiteren DOM-Eingriffe.
            let busyProbe = """
            (function() {
              const root = document.body || document.documentElement;
              if (!root) return false;
              const text = (root.innerText || root.textContent || '').slice(0, 8000);
              return /Anmelden\\s*\\.\\.\\./i.test(text)
                || /Signing\\s*in\\s*\\.\\.\\./i.test(text)
                || /Logging\\s*in\\s*\\.\\.\\./i.test(text);
            })();
            """
            webView.evaluateJavaScript(busyProbe) { [weak self] result, _ in
                guard let self else { return }
                let busy = (result as? Bool) ?? false
                // #region agent log
                AgentDebugLog.write(
                    hypothesisId: "F,H",
                    location: "ProviderSessionView.swift:applyLoginAssistance.busyProbe",
                    message: "login busy probe",
                    data: ["busy": busy, "url": url.absoluteString]
                )
                // #endregion
                if busy {
                    Task { @MainActor in
                        self.suspendLoginAssistance()
                    }
                    return
                }
                Task { @MainActor in
                    self.runLoginAssistanceScripts(in: webView, url: url)
                }
            }
        }

        @MainActor
        private func runLoginAssistanceScripts(in webView: WKWebView, url: URL) {
            guard !loginAssistanceSuspended else { return }
            guard let credentials = autofillCredentials else {
                // #region agent log
                AgentDebugLog.write(
                    hypothesisId: "S",
                    location: "ProviderSessionView.swift:applyLoginAssistance",
                    message: "login assistance noop (no credentials)",
                    data: ["url": url.absoluteString]
                )
                // #endregion
                return
            }
            // #region agent log
            AgentDebugLog.write(
                hypothesisId: "S",
                location: "ProviderSessionView.swift:applyLoginAssistance",
                message: "login assistance autofill",
                data: [
                    "usernameLen": credentials.username.count,
                    "url": url.absoluteString,
                ]
            )
            // #endregion
            LoginAutofill.apply(in: webView, credentials: credentials)
        }

        // MARK: - WKUIDelegate (Popups / target=_blank)

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            let url = navigationAction.request.url?.absoluteString ?? "nil"
            // #region agent log
            AgentDebugLog.write(
                hypothesisId: "Q",
                location: "ProviderSessionView.swift:createWebViewWith",
                message: "popup/createWebView requested",
                data: [
                    "url": String(url.prefix(300)),
                    "hasTargetFrame": navigationAction.targetFrame != nil,
                ]
            )
            // #endregion
            // Ohne Handler gehen target=_blank/SSO-Fenster verloren → Login hängt.
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        private func updateSession(from webView: WKWebView) {
            guard let url = webView.url else { return }
            lastURLString.wrappedValue = url.absoluteString

            let absolute = url.absoluteString.lowercased()
            let looksLikeLogin = AuthPageURLHeuristic.looksLikeLoginPage(absolute)
            let looksLikeAccount = AuthPageURLHeuristic.looksLikeAccountPage(absolute)
            let statusHeuristic = ProviderSessionStatusResolver.classify(url)

            // #region agent log
            AgentDebugLog.write(
                hypothesisId: "E",
                location: "ProviderSessionView.swift:updateSession",
                message: "URL classification",
                data: [
                    "url": url.absoluteString,
                    "looksLikeLogin": looksLikeLogin,
                    "looksLikeAccount": looksLikeAccount,
                    "statusBefore": "\(sessionStatus.wrappedValue)",
                ]
            )
            // #endregion

            switch statusHeuristic {
            case .sessionReady:
                sessionStatus.wrappedValue = .sessionReady
            case .needsLogin:
                sessionStatus.wrappedValue = .needsLogin
            case .shouldProbeOpodo:
                // Homepage nach Login: weder Login- noch Account-URL → GraphQL-Probe.
                scheduleOpodoSessionProbe(in: webView)
            case .unknown:
                break
            }

            if looksLikeLogin, !loginAssistanceSuspended {
                Task { @MainActor in
                    scheduleLoginAssistance(in: webView)
                }
            }

            // OTP-Hints nicht auf Account-Seiten — nur Login/OTP-Challenge.
            let wantsOTP = AuthPageURLHeuristic.looksLikeOneTimeCodeChallenge(absolute)
                || (looksLikeLogin && !loginAssistanceSuspended)
            if wantsOTP {
                OneTimeCodeAutofill.apply(in: webView)
            }
        }

        @MainActor
        private func scheduleOpodoSessionProbe(in webView: WKWebView) {
            sessionProbeWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self, weak webView] in
                guard let self, let webView else { return }
                self.runOpodoSessionProbe(in: webView)
            }
            sessionProbeWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
        }

        @MainActor
        private func runOpodoSessionProbe(in webView: WKWebView) {
            guard let url = webView.url, OpodoSessionProbe.applies(to: url) else { return }
            // Secure-URL ist bereits Account — Probe nur wenn Heuristik unklar.
            let absolute = url.absoluteString.lowercased()
            if AuthPageURLHeuristic.looksLikeAccountPage(absolute),
               !AuthPageURLHeuristic.looksLikeLoginPage(absolute) {
                return
            }

            Task { @MainActor [weak self, weak webView] in
                guard let self, let webView else { return }
                do {
                    let text = try await webView.fetchAuthenticatedText(
                        url: OpodoSessionProbe.graphqlURL,
                        method: "POST",
                        accept: "application/json",
                        referer: "https://www.opodo.de/",
                        contentType: "application/json",
                        body: OpodoSessionProbe.getUserAccountRequestBody()
                    )
                    let loggedIn = OpodoSessionProbe.isLoggedIn(fromGraphQLJSON: text)
                    // #region agent log
                    AgentDebugLog.write(
                        hypothesisId: "Z2",
                        location: "ProviderSessionView.swift:runOpodoSessionProbe",
                        message: "Opodo GetUserAccount probe",
                        data: [
                            "loggedIn": loggedIn as Any,
                            "bodyPrefix": String(text.prefix(160)),
                        ]
                    )
                    // #endregion
                    if loggedIn == true {
                        self.sessionStatus.wrappedValue = .sessionReady
                        self.suspendLoginAssistance()
                    } else if loggedIn == false {
                        self.sessionStatus.wrappedValue = .needsLogin
                    }
                } catch {
                    // #region agent log
                    AgentDebugLog.write(
                        hypothesisId: "Z2",
                        location: "ProviderSessionView.swift:runOpodoSessionProbe",
                        message: "Opodo GetUserAccount probe failed",
                        data: ["error": error.localizedDescription]
                    )
                    // #endregion
                }
            }
        }
    }
}

// #region agent log
enum AgentDebugLog {
    private static let path = "/Users/roschmac/Entwicklung/Reisen/.cursor/debug-33f094.log"
    private static let lock = NSLock()

    static func write(
        hypothesisId: String,
        location: String,
        message: String,
        data: [String: Any] = [:]
    ) {
        lock.lock()
        defer { lock.unlock() }
        let payload: [String: Any] = [
            "sessionId": "33f094",
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "data": data,
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let json = try? JSONSerialization.data(withJSONObject: payload),
              var line = String(data: json, encoding: .utf8) else { return }
        line.append("\n")
        let url = URL(fileURLWithPath: path)
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: Data(line.utf8))
            return
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(line.utf8))
    }
}
// #endregion
