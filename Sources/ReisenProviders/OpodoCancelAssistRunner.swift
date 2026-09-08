import Foundation
import WebKit
import ReisenDiagnostics
import ReisenDomain

/// Opens Opodo cancel confirm dialog; never clicks final storno confirm.
@MainActor
public final class OpodoCancelAssistRunner {
    private let oneShot = PortalCancelAssistOneShot()
    /// Fired when Assist sees Domain completion marker (`bereits storniert`).
    public var onAlreadyCancelled: (() -> Void)?

    public init() {}

    public func reset() {
        oneShot.reset()
    }

    public func webViewDidFinish(_ webView: WKWebView, provider: ProviderID) {
        let started = oneShot.startIfNeeded(
            shouldRun: OpodoCancelAssist.shouldRun(provider: provider, loadedURL: webView.url)
        ) { [weak self] in
            await self?.runAssist(on: webView)
        }
        guard started else { return }
        record(result: .started, reason: "trip_details_loaded")
    }

    private func runAssist(on webView: WKWebView) async {
        let deadline = ContinuousClock.now + .nanoseconds(
            Int64(PortalCancelAssistSupport.pollTimeoutNanoseconds)
        )
        while !Task.isCancelled, ContinuousClock.now < deadline {
            let step = await evaluateStep(webView)
            switch step {
            case .alreadyOpen:
                record(result: .succeeded, reason: "dialog_already_open")
                return
            case .clickedEntry:
                record(result: .started, reason: "entry_clicked")
                await pollDialog(on: webView, deadline: deadline)
                return
            case .alreadyCancelled:
                record(result: .skipped, reason: "already_cancelled")
                onAlreadyCancelled?()
                return
            case .wrongHost:
                record(result: .skipped, reason: "wrong_host")
                return
            case .entryMissing, nil:
                break
            }
            try? await Task.sleep(nanoseconds: PortalCancelAssistSupport.pollIntervalNanoseconds)
        }
        if !Task.isCancelled {
            record(result: .failed, reason: "entry_missing")
        }
    }

    private func pollDialog(on webView: WKWebView, deadline: ContinuousClock.Instant) async {
        var sawDialog = false
        while !Task.isCancelled, ContinuousClock.now < deadline {
            switch await evaluatePoll(webView) {
            case .dialogOpen:
                if !sawDialog {
                    sawDialog = true
                    record(result: .succeeded, reason: "dialog_open")
                }
                // Keep watching: user may confirm; SPA may show already-cancelled without didFinish.
            case .alreadyCancelled:
                record(result: .skipped, reason: "already_cancelled")
                onAlreadyCancelled?()
                return
            case .pending, nil:
                break
            }
            try? await Task.sleep(nanoseconds: PortalCancelAssistSupport.pollIntervalNanoseconds)
        }
        if !Task.isCancelled {
            record(
                result: sawDialog ? .succeeded : .failed,
                reason: sawDialog ? "dialog_open_no_completion" : "assist_timeout"
            )
        }
    }

    private func evaluateStep(_ webView: WKWebView) async -> OpodoCancelAssistScript.StepStatus? {
        OpodoCancelAssistScript.parseStepStatus(
            await webView.evaluateJavaScriptStringResult(OpodoCancelAssistScript.step)
        )
    }

    private func evaluatePoll(_ webView: WKWebView) async -> OpodoCancelAssistScript.PollStatus? {
        OpodoCancelAssistScript.parsePollStatus(
            await webView.evaluateJavaScriptStringResult(OpodoCancelAssistScript.poll)
        )
    }

    private func record(result: DiagnosticResult, reason: String) {
        PortalCancelAssistSupport.record(
            providerID: .opodo,
            component: OpodoCancelAssist.component,
            result: result,
            reason: reason
        )
    }
}
