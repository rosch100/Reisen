import SwiftUI
import WebKit
import AppKit
import ReisenDomain
import ReisenProviders
import ReisenAppCore

/// Vollflächiger Provider-Browser für alle Provider (Check24, Opodo, Booking.com, …).
/// Kein ScrollView/Form-Container — sonst ist der Login auf macOS oft nicht bedienbar.
struct ProviderSessionView: View {
    let providerID: ProviderID
    let loginURL: URL?
    @Binding var sessionStatus: ProviderSessionStatus
    @Binding var lastURLString: String?
    @Binding var webView: WKWebView?

    let autofillCredentials: ProviderCredentials?
    let onCapturedCredentials: ((ProviderCredentials) -> Void)?
    let onNavigationBlocked: (() -> Void)?
    let allowsEmbed: Bool
    let diagnosticContext: DiagnosticContext

    init(
        providerID: ProviderID,
        loginURL: URL?,
        sessionStatus: Binding<ProviderSessionStatus>,
        lastURLString: Binding<String?>,
        webView: Binding<WKWebView?>,
        autofillCredentials: ProviderCredentials? = nil,
        onCapturedCredentials: ((ProviderCredentials) -> Void)? = nil,
        onNavigationBlocked: (() -> Void)? = nil,
        allowsEmbed: Bool,
        diagnosticContext: DiagnosticContext
    ) {
        self.providerID = providerID
        self.loginURL = loginURL
        self._sessionStatus = sessionStatus
        self._lastURLString = lastURLString
        self._webView = webView
        self.autofillCredentials = autofillCredentials
        self.onCapturedCredentials = onCapturedCredentials
        self.onNavigationBlocked = onNavigationBlocked
        self.allowsEmbed = allowsEmbed
        self.diagnosticContext = diagnosticContext
    }

    var body: some View {
        ProviderWebView(
            loginURL: loginURL,
            sessionStatus: $sessionStatus,
            lastURLString: $lastURLString,
            webViewRef: $webView,
            autofillCredentials: autofillCredentials,
            onCapturedCredentials: onCapturedCredentials,
            onNavigationBlocked: onNavigationBlocked,
            allowsEmbed: allowsEmbed,
            diagnosticContext: diagnosticContext
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
    let onCapturedCredentials: ((ProviderCredentials) -> Void)?
    let onNavigationBlocked: (() -> Void)?
    let allowsEmbed: Bool
    let diagnosticContext: DiagnosticContext

    func makeCoordinator() -> Coordinator {
        Coordinator(
            sessionStatus: $sessionStatus,
            lastURLString: $lastURLString,
            autofillCredentials: autofillCredentials,
            onCapturedCredentials: onCapturedCredentials,
            onNavigationBlocked: onNavigationBlocked,
            diagnosticContext: diagnosticContext
        )
    }

    func makeNSView(context: Context) -> WebViewHostView {
        let host = WebViewHostView(frame: .zero)
        guard allowsEmbed else { return host }
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
            onCapturedCredentials: onCapturedCredentials,
            onNavigationBlocked: onNavigationBlocked,
            diagnosticContext: diagnosticContext
        )

        guard allowsEmbed else { return }

        let webView = resolveWebView(context: context)
        if credentialsChanged {
            ProviderLoginAssistance.resetAssistanceScheduling(for: webView)
        }
        // Auch neu einbinden, wenn die Property noch gesetzt ist, der WebView aber
        // inzwischen in einem anderen Host (Hintergrund-Bootstrap) hängt.
        if nsView.webView !== webView || webView.superview !== nsView {
            nsView.embed(webView)
            context.coordinator.recordLifecycleEvent(
                "webview_reparented",
                webView: webView
            )
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
            context.coordinator.scheduleLoginAssistance(in: webView)
        }
    }

    static func dismantleNSView(_ nsView: WebViewHostView, coordinator: Coordinator) {
        // Wenn die WebView bereits in einen anderen Host übernommen wurde
        // (sichtbarer SyncView vs. 1×1-Bootstrap), Delegates dort nicht zerstören.
        if let webView = nsView.webView, webView.superview === nsView {
            let ucc = webView.configuration.userContentController
            ucc.removeScriptMessageHandler(forName: LoginFieldHints.messageHandlerName)
            LoginSubmitBusyProbe.removeMessageHandler(from: ucc)
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
        config.preferences.isElementFullscreenEnabled = true
        config.userContentController.add(context.coordinator, name: LoginFieldHints.messageHandlerName)
        config.userContentController.add(context.coordinator, name: LoginFormCapture.messageHandlerName)
        LoginSubmitBusyProbe.addMessageHandler(to: config.userContentController, handler: context.coordinator)
        LoginSubmitBusyProbe.addUserScript(to: config.userContentController)

        let webView = FocusableWKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.recordLifecycleEvent(
            "webview_created",
            webView: webView
        )
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
        ucc.removeScriptMessageHandler(forName: LoginFormCapture.messageHandlerName)
        ucc.add(context.coordinator, name: LoginFormCapture.messageHandlerName)
        LoginSubmitBusyProbe.addMessageHandler(to: ucc, handler: context.coordinator)
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
        private var onCapturedCredentials: ((ProviderCredentials) -> Void)?
        private var onNavigationBlocked: (() -> Void)?
        private var becomeKeyObserver: NSObjectProtocol?
        private weak var trackedWebView: WKWebView?
        private var loginAssistanceWorkItem: DispatchWorkItem?
        private var loginAssistanceCancellation: ProviderLoginAssistanceCancellation?
        private var sessionProbeWorkItem: DispatchWorkItem?
        private var sessionProbeTask: Task<Void, Never>?
        private var diagnosticContext: DiagnosticContext
        var loadedLoginURL: URL?
        private var lastObservedURL: URL?
        /// Während „Anmelden…“ (Post-Submit) keine DOM-Hilfe mehr.
        private var loginAssistanceSuspended = false

        init(
            sessionStatus: Binding<ProviderSessionStatus>,
            lastURLString: Binding<String?>,
            autofillCredentials: ProviderCredentials?,
            onCapturedCredentials: ((ProviderCredentials) -> Void)?,
        onNavigationBlocked: (() -> Void)?,
        diagnosticContext: DiagnosticContext
        ) {
            self.sessionStatus = sessionStatus
            self.lastURLString = lastURLString
            self.autofillCredentials = autofillCredentials
            self.onCapturedCredentials = onCapturedCredentials
            self.onNavigationBlocked = onNavigationBlocked
            self.diagnosticContext = diagnosticContext
        }

        func update(
            sessionStatus: Binding<ProviderSessionStatus>,
            lastURLString: Binding<String?>,
            onCapturedCredentials: ((ProviderCredentials) -> Void)?,
            onNavigationBlocked: (() -> Void)?,
            diagnosticContext: DiagnosticContext
        ) {
            self.sessionStatus = sessionStatus
            self.lastURLString = lastURLString
            self.onCapturedCredentials = onCapturedCredentials
            self.onNavigationBlocked = onNavigationBlocked
            self.diagnosticContext = diagnosticContext
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
            loginAssistanceCancellation?.cancel()
            loginAssistanceCancellation = nil
            sessionProbeWorkItem?.cancel()
            sessionProbeWorkItem = nil
            if let becomeKeyObserver {
                NotificationCenter.default.removeObserver(becomeKeyObserver)
            }
            becomeKeyObserver = nil
            trackedWebView = nil
            lastObservedURL = nil
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == LoginSubmitBusyProbe.messageHandlerName {
                handleLoginBusyMessage(message)
                return
            }
            if message.name == LoginFormCapture.messageHandlerName {
                LoginFormCapture.handleScriptMessage(
                    message,
                    webView: trackedWebView ?? message.webView
                ) { credentials in
                    onCapturedCredentials?(credentials)
                }
                return
            }
            guard message.name == LoginFieldHints.messageHandlerName else { return }
            guard let webView = trackedWebView ?? message.webView else { return }
            Task { @MainActor in
                guard !loginAssistanceSuspended else { return }
                scheduleLoginAssistance(in: webView)
            }
        }

        private func handleLoginBusyMessage(_ message: WKScriptMessage) {
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
            if type == "busy", body["busy"] as? Bool == true {
                recordEvent(
                    "login_busy_started",
                    phase: "autofill",
                    result: .started,
                    webView: trackedWebView ?? message.webView
                )
                Task { @MainActor in
                    self.suspendLoginAssistance()
                }
            } else if type == "busy", body["busy"] as? Bool == false {
                recordEvent(
                    "login_busy_ended",
                    phase: "autofill",
                    result: .succeeded,
                    webView: trackedWebView ?? message.webView
                )
                Task { @MainActor in
                    if let webView = self.trackedWebView ?? message.webView {
                        self.updateSession(from: webView)
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            recordNavigationEvent(
                "did_finish",
                result: .succeeded,
                webView: webView
            )
            updateSession(from: webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            recordNavigationEvent(
                "did_commit",
                result: .started,
                webView: webView
            )
            updateSession(from: webView)
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
        }

        private func recordNavigationEvent(
            _ event: String,
            result: DiagnosticResult,
            webView: WKWebView,
            error: Error? = nil,
            reason: String? = nil
        ) {
            recordDiagnostic(
                event,
                phase: "navigation",
                result: result,
                webView: webView,
                error: error,
                reason: reason
            )
        }

        private func recordEvent(
            _ event: String,
            phase: String,
            result: DiagnosticResult,
            webView: WKWebView?,
            reason: String? = nil
        ) {
            guard let webView else { return }
            recordDiagnostic(
                event,
                phase: phase,
                result: result,
                webView: webView,
                reason: reason
            )
        }

        func recordLifecycleEvent(_ event: String, webView: WKWebView) {
            recordDiagnostic(
                event,
                phase: "lifecycle",
                result: .succeeded,
                webView: webView
            )
        }

        private func recordDiagnostic(
            _ event: String,
            phase: String,
            result: DiagnosticResult,
            webView: WKWebView,
            error: Error? = nil,
            reason: String? = nil,
            statusBefore: ProviderSessionStatus? = nil,
            statusAfter: ProviderSessionStatus? = nil
        ) {
            let diagnosticEvent = DiagnosticEvent(
                context: diagnosticContext,
                component: "ProviderSessionView",
                phase: phase,
                event: event,
                result: result,
                url: webView.url?.absoluteString,
                errorType: error.map { String(reflecting: type(of: $0)) },
                reason: reason ?? error.map { DiagnosticRedactor.redact($0.localizedDescription) },
                statusBefore: statusBefore.map { String(describing: $0) },
                statusAfter: statusAfter.map { String(describing: $0) }
            )
            Task { await DiagnosticLogger.shared.record(diagnosticEvent) }
        }

        @MainActor
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
        ) {
            let isMain = navigationAction.targetFrame?.isMainFrame ?? false
            if let requestURL = navigationAction.request.url,
               !ProviderWebViewNavigationPolicy.allows(requestURL, isMainFrame: isMain) {
                recordNavigationEvent(
                    "navigation_blocked",
                    result: .skipped,
                    webView: webView,
                    reason: "navigation_policy"
                )
                onNavigationBlocked?()
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        @MainActor
        func scheduleLoginAssistance(in webView: WKWebView) {
            guard ProviderLoginAssistance.shouldScheduleAssistance(in: webView) else { return }
            loginAssistanceWorkItem?.cancel()
            loginAssistanceCancellation?.cancel()
            loginAssistanceCancellation = nil
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
            if let webView = trackedWebView {
                ProviderLoginAssistance.resetAssistanceScheduling(for: webView)
            }
            loginAssistanceWorkItem?.cancel()
            loginAssistanceWorkItem = nil
            loginAssistanceCancellation?.cancel()
            loginAssistanceCancellation = nil
        }

        @MainActor
        func applyLoginAssistance(in webView: WKWebView) {
            guard let url = webView.url else { return }
            let absolute = url.absoluteString.lowercased()
            let isLogin = AuthPageURLHeuristic.shouldApplyPasswordAutofill(absolute)
            guard isLogin else {
                loginAssistanceSuspended = false
                return
            }
            guard !loginAssistanceSuspended else { return }

            // Während „Anmelden…“ keine weiteren DOM-Eingriffe (Busy-SSOT: LoginSubmitBusyProbe).
            webView.evaluateJavaScript(LoginSubmitBusyProbe.isBusyEvaluateScript) { [weak self] result, _ in
                guard let self else { return }
                let busy = (result as? Bool) ?? false
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
                return
            }
            loginAssistanceCancellation = ProviderLoginAssistance.applyCredentials(
                in: webView,
                credentials: credentials,
                diagnosticContext: diagnosticContext
            )
        }

        // MARK: - WKUIDelegate (Popups / target=_blank)

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Ohne Handler gehen target=_blank/SSO-Fenster verloren → Login hängt.
            if navigationAction.targetFrame == nil {
                if let requestURL = navigationAction.request.url {
                    if ProviderWebViewNavigationPolicy.allows(requestURL, isMainFrame: true) {
                        recordNavigationEvent(
                            "popup_reparented",
                            result: .succeeded,
                            webView: webView,
                            reason: "loaded_in_existing_webview"
                        )
                        webView.load(navigationAction.request)
                    } else {
                        recordNavigationEvent(
                            "popup_blocked",
                            result: .skipped,
                            webView: webView,
                            reason: "navigation_policy"
                        )
                        onNavigationBlocked?()
                    }
                }
            }
            return nil
        }

        private func updateSession(from webView: WKWebView) {
            guard let url = webView.url else { return }
            if lastObservedURL != url {
                recordEvent(
                    "login_page_changed",
                    phase: "session",
                    result: .started,
                    webView: webView
                )
                lastObservedURL = url
            }
            lastURLString.wrappedValue = url.absoluteString

            let absolute = url.absoluteString.lowercased()
            let looksLikeLogin = AuthPageURLHeuristic.looksLikeLoginPage(absolute)
            let statusHeuristic = ProviderSessionStatusResolver.classify(url)

            switch statusHeuristic {
            case .sessionReady:
                let wasReady = sessionStatus.wrappedValue == .sessionReady
                sessionStatus.wrappedValue = .sessionReady
                if !wasReady {
                    recordEvent(
                        "session_ready",
                        phase: "session",
                        result: .succeeded,
                        webView: webView
                    )
                }
            case .needsLogin:
                sessionStatus.wrappedValue = .needsLogin
            case .shouldProbeOpodo, .shouldProbeTraveloka, .shouldProbeBilligerMietwagen, .shouldProbeCheck24:
                guard let liveProbe = ProviderSessionLiveProbe.prepare(
                    statusHeuristic,
                    sessionAlreadyReady: sessionStatus.wrappedValue == .sessionReady,
                    url: url
                ) else { break }
                scheduleSessionProbe(
                    in: webView,
                    applies: liveProbe.applies,
                    skipAccountPage: liveProbe.skipsAccountPage
                ) { [weak self] webView in
                    let hints = self?.lastURLString.wrappedValue.flatMap(URL.init(string:)).map { [$0] } ?? []
                    return try await ProviderSessionLiveProbe.fetchIsLoggedIn(
                        statusHeuristic,
                        using: webView,
                        additionalHintURLs: hints
                    )
                }
            case .unknown:
                break
            }

            if looksLikeLogin, !loginAssistanceSuspended {
                Task { @MainActor in
                    scheduleLoginAssistance(in: webView)
                }
            }

            if AuthPageURLHeuristic.shouldApplyPasswordAutofill(absolute) {
                ProviderLoginAssistance.installOnLoginPage(
                    in: webView,
                    diagnosticContext: diagnosticContext
                )
            }

            // OTP-Hints nicht auf Account-Seiten — nur Login/OTP-Challenge.
            let wantsOTP = AuthPageURLHeuristic.shouldApplyOneTimeCodeAutofill(absolute)
                && !loginAssistanceSuspended
            if wantsOTP {
                OneTimeCodeAutofill.apply(in: webView)
            }
        }

        @MainActor
        private func scheduleSessionProbe(
            in webView: WKWebView,
            applies: @escaping (URL) -> Bool,
            skipAccountPage: Bool = false,
            probe: @escaping @MainActor (WKWebView) async throws -> Bool?
        ) {
            scheduleDelayedSessionProbe(in: webView) { [weak self] webView in
                self?.runSessionProbe(
                    in: webView,
                    applies: applies,
                    skipAccountPage: skipAccountPage,
                    probe: probe
                )
            }
        }

        @MainActor
        private func runSessionProbe(
            in webView: WKWebView,
            applies: (URL) -> Bool,
            skipAccountPage: Bool = false,
            probe: @escaping @MainActor (WKWebView) async throws -> Bool?
        ) {
            guard hasNavigationHint(in: webView, applies: applies) else { return }
            if skipAccountPage, shouldSkipAccountPageProbe(in: webView) { return }

            sessionProbeTask?.cancel()
            sessionProbeTask = Task { @MainActor [weak self, weak webView] in
                guard let self, let webView else { return }
                let statusBefore = self.sessionStatus.wrappedValue
                self.recordProbeEvent(
                    "started",
                    result: .started,
                    webView: webView,
                    statusBefore: statusBefore
                )
                do {
                    let loggedIn = try await probe(webView)
                    if NetworkErrorClassification.isCurrentTaskCancelled {
                        self.recordProbeCancellation(webView: webView, statusBefore: statusBefore)
                        return
                    }
                    guard let loggedIn else {
                        self.recordProbeEvent(
                            "unknown",
                            result: .skipped,
                            webView: webView,
                            reason: "probe_returned_unknown",
                            statusBefore: statusBefore
                        )
                        return
                    }
                    self.applySessionProbeOutcome(loggedIn)
                    self.recordProbeEvent(
                        "completed",
                        result: .succeeded,
                        webView: webView,
                        reason: loggedIn ? "session_ready" : "needs_login",
                        statusBefore: statusBefore,
                        statusAfter: self.sessionStatus.wrappedValue
                    )
                } catch {
                    if NetworkErrorClassification.isCancellation(error) {
                        self.recordProbeCancellation(webView: webView, statusBefore: statusBefore)
                        return
                    }
                    let timedOut = NetworkErrorClassification.isURLTimeout(error)
                    self.recordProbeEvent(
                        timedOut ? "timeout" : "failed",
                        result: timedOut ? .timedOut : .failed,
                        webView: webView,
                        error: error,
                        statusBefore: statusBefore
                    )
                }
            }
        }

        @MainActor
        private func scheduleDelayedSessionProbe(
            in webView: WKWebView,
            run: @escaping @MainActor (WKWebView) -> Void
        ) {
            sessionProbeWorkItem?.cancel()
            sessionProbeTask?.cancel()
            sessionProbeTask = nil
            let work = DispatchWorkItem { [weak webView] in
                guard let webView else { return }
                run(webView)
            }
            sessionProbeWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
        }

        private func shouldSkipAccountPageProbe(in webView: WKWebView) -> Bool {
            guard let url = webView.url else { return false }
            let absolute = url.absoluteString.lowercased()
            return AuthPageURLHeuristic.looksLikeAccountPage(absolute)
                && !AuthPageURLHeuristic.looksLikeLoginPage(absolute)
        }

        private func hasNavigationHint(in webView: WKWebView, applies: (URL) -> Bool) -> Bool {
            if let url = webView.url, applies(url) { return true }
            if let hint = lastURLString.wrappedValue.flatMap(URL.init(string:)), applies(hint) {
                return true
            }
            return false
        }

        private func applySessionProbeOutcome(_ loggedIn: Bool) {
            if loggedIn {
                suspendLoginAssistance()
            }
            sessionStatus.wrappedValue = .fromProbe(loggedIn: loggedIn)
        }

        private func recordProbeCancellation(
            webView: WKWebView,
            statusBefore: ProviderSessionStatus
        ) {
            recordProbeEvent(
                "cancelled",
                result: .cancelled,
                webView: webView,
                reason: "task_cancelled",
                statusBefore: statusBefore
            )
        }

        private func recordProbeEvent(
            _ event: String,
            result: DiagnosticResult,
            webView: WKWebView,
            error: Error? = nil,
            reason: String? = nil,
            statusBefore: ProviderSessionStatus? = nil,
            statusAfter: ProviderSessionStatus? = nil
        ) {
            recordDiagnostic(
                event,
                phase: "session_probe",
                result: result,
                webView: webView,
                error: error,
                reason: reason,
                statusBefore: statusBefore,
                statusAfter: statusAfter
            )
        }
    }
}

