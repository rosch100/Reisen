import Foundation
import WebKit
import ReisenDiagnostics
import ReisenDomain

/// Evaluates cancel-sheet page text for `PortalCancelCompletionDetector`.
@MainActor
public enum PortalCancelCompletionProbe {
    public static let component = "PortalCancelCompletionProbe"
    public static let phase = "detect"
    public static let operation = "portal_cancel_completion"
    public static let maxInnerTextCharacters = 20_000

    public static let innerTextScript = """
    (function() {
      var t = (document.body && document.body.innerText) || '';
      return t.slice(0, \(maxInnerTextCharacters));
    })()
    """

    public static func evaluateIfNeeded(
        webView: WKWebView,
        provider: ProviderID,
        onDetected: @escaping () -> Void
    ) {
        guard PortalCancelCompletionDetector.needsPageTextProbe(provider: provider) else {
            return
        }
        Task { @MainActor in
            let pageText = await webView.evaluateJavaScriptStringResult(innerTextScript)
            let url = webView.url
            guard PortalCancelCompletionDetector.looksCompleted(
                provider: provider,
                url: url,
                pageText: pageText
            ) else {
                return
            }
            recordDetected(provider: provider, url: url)
            onDetected()
        }
    }

    private static func recordDetected(provider: ProviderID, url: URL?) {
        let event = DiagnosticEvent(
            context: DiagnosticContext(
                runID: UUID(),
                providerID: provider,
                operation: operation
            ),
            component: component,
            phase: phase,
            event: "portal_cancel_completion_detected",
            result: .succeeded,
            url: url.flatMap(DiagnosticRedactor.urlMetadata(for:)),
            reason: "marker_matched"
        )
        Task {
            await DiagnosticLogger.shared.record(event)
        }
    }
}
