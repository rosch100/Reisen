import Foundation
import WebKit
import ReisenDiagnostics
import ReisenDomain

/// Runs BM cancel assist once per sheet load on the hub WKWebView.
@MainActor
public final class BilligerMietwagenCancelAssistRunner {
    private let oneShot = PortalCancelAssistOneShot()

    public init() {}

    public func reset() {
        oneShot.reset()
    }

    public func webViewDidFinish(_ webView: WKWebView, provider: ProviderID) {
        let started = oneShot.startIfNeeded(
            shouldRun: BilligerMietwagenCancelAssist.shouldRun(
                provider: provider,
                loadedURL: webView.url
            )
        ) { [weak self] in
            await self?.runAssist(on: webView)
        }
        guard started else { return }
        record(result: .started, reason: "booking_detail_loaded")
    }

    private func runAssist(on webView: WKWebView) async {
        let deadline = ContinuousClock.now + .nanoseconds(
            Int64(PortalCancelAssistSupport.pollTimeoutNanoseconds)
        )
        while !Task.isCancelled, ContinuousClock.now < deadline {
            let click = await evaluateClick(webView)
            switch click {
            case .alreadyScoped:
                record(result: .succeeded, reason: "already_scoped")
                return
            case .clicked:
                record(result: .started, reason: "cancel_control_clicked")
                await pollScopedForm(on: webView, deadline: deadline)
                return
            case .genericForm:
                record(result: .failed, reason: "generic_form")
                return
            case .cancelUnknown:
                record(result: .failed, reason: "cancel_unknown")
                return
            case .wrongHost:
                record(result: .skipped, reason: "wrong_host")
                return
            case .buttonMissing, nil:
                break
            }
            try? await Task.sleep(nanoseconds: PortalCancelAssistSupport.pollIntervalNanoseconds)
        }
        if !Task.isCancelled {
            record(result: .failed, reason: "button_missing")
        }
    }

    private func pollScopedForm(on webView: WKWebView, deadline: ContinuousClock.Instant) async {
        while !Task.isCancelled, ContinuousClock.now < deadline {
            switch await evaluatePoll(webView) {
            case .scoped:
                record(result: .succeeded, reason: "scoped_cancel_form")
                return
            case .generic:
                record(result: .failed, reason: "generic_after_click")
                return
            case .pending, nil:
                break
            }
            try? await Task.sleep(nanoseconds: PortalCancelAssistSupport.pollIntervalNanoseconds)
        }
        if !Task.isCancelled {
            record(result: .failed, reason: "assist_timeout")
        }
    }

    private func evaluateClick(
        _ webView: WKWebView
    ) async -> BilligerMietwagenCancelAssistScript.ClickStatus? {
        BilligerMietwagenCancelAssistScript.parseClickStatus(
            await webView.evaluateJavaScriptStringResult(BilligerMietwagenCancelAssistScript.click)
        )
    }

    private func evaluatePoll(
        _ webView: WKWebView
    ) async -> BilligerMietwagenCancelAssistScript.PollStatus? {
        BilligerMietwagenCancelAssistScript.parsePollStatus(
            await webView.evaluateJavaScriptStringResult(BilligerMietwagenCancelAssistScript.poll)
        )
    }

    private func record(result: DiagnosticResult, reason: String) {
        PortalCancelAssistSupport.record(
            providerID: .billigerMietwagen,
            component: BilligerMietwagenCancelAssist.component,
            result: result,
            reason: reason
        )
    }
}
