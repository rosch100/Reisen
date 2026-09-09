import Foundation
import WebKit
import ReisenDiagnostics
import ReisenDomain

/// Opens Expedia car cancel dialog and confirms (DE HAR); polls until dialog gone.
@MainActor
public final class ExpediaCarCancelAssistRunner {
    private let oneShot = PortalCancelAssistOneShot()

    public init() {}

    public func reset() {
        oneShot.reset()
    }

    public func webViewDidFinish(
        _ webView: WKWebView,
        provider: ProviderID,
        bookingType: BookingType?
    ) {
        let started = oneShot.startIfNeeded(
            shouldRun: ExpediaCarCancelAssist.shouldRun(
                provider: provider,
                loadedURL: webView.url,
                bookingType: bookingType
            )
        ) { [weak self] in
            await self?.runAssist(on: webView)
        }
        guard started else { return }
        record(result: .started, reason: "manage_booking_loaded")
    }

    private func runAssist(on webView: WKWebView) async {
        let deadline = ContinuousClock.now + .nanoseconds(
            Int64(PortalCancelAssistSupport.pollTimeoutNanoseconds)
        )
        var clickedConfirm = false
        while !Task.isCancelled, ContinuousClock.now < deadline {
            let step = await evaluateStep(webView)
            switch step {
            case .clickedConfirm:
                record(result: .started, reason: "confirm_clicked")
                clickedConfirm = true
                await pollDialogGone(on: webView, deadline: deadline)
                return
            case .alreadyConfirm:
                record(result: .started, reason: "confirm_visible")
                // Click confirm on next loop.
            case .clickedEntry:
                record(result: .started, reason: "entry_clicked")
            case .dialogGone:
                // Confirm success is handled in `pollDialogGone` after `.clickedConfirm`.
                break
            case .notCarCancel:
                record(result: .skipped, reason: "not_car_cancel")
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
            record(result: .failed, reason: clickedConfirm ? "assist_timeout" : "entry_missing")
        }
    }

    private func pollDialogGone(on webView: WKWebView, deadline: ContinuousClock.Instant) async {
        var sawOpen = false
        while !Task.isCancelled, ContinuousClock.now < deadline {
            switch await evaluatePoll(webView) {
            case .dialogOpen:
                sawOpen = true
            case .dialogGone:
                record(
                    result: .succeeded,
                    reason: sawOpen ? "dialog_gone_after_confirm" : "dialog_gone"
                )
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

    private func evaluateStep(_ webView: WKWebView) async -> ExpediaCarCancelAssistScript.StepStatus? {
        ExpediaCarCancelAssistScript.parseStepStatus(
            await webView.evaluateJavaScriptStringResult(ExpediaCarCancelAssistScript.step)
        )
    }

    private func evaluatePoll(_ webView: WKWebView) async -> ExpediaCarCancelAssistScript.PollStatus? {
        ExpediaCarCancelAssistScript.parsePollStatus(
            await webView.evaluateJavaScriptStringResult(ExpediaCarCancelAssistScript.poll)
        )
    }

    private func record(result: DiagnosticResult, reason: String) {
        PortalCancelAssistSupport.record(
            providerID: .expedia,
            component: ExpediaCarCancelAssist.component,
            result: result,
            reason: reason
        )
    }
}
