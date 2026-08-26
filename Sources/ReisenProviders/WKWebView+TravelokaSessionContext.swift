import Foundation
import WebKit

extension WKWebView {
    /// Liest Traveloka-Session-Kontext aus Cookies, Navigationsverlauf und Web Storage.
    ///
    /// Funktioniert unabhängig von der aktuellen Seite (nach Login, Homepage, Detail, …).
    public func travelokaSessionContext(additionalHintURLs: [URL] = []) async -> TravelokaSessionContext {
        var context = TravelokaSessionContext.from(cookies: await allHTTPCookies())
        let hints = navigationHintURLs(additionalHintURLs: additionalHintURLs)
        context.applyNavigationHints(from: hints)

        let shouldScanStorage = hints.contains(where: TravelokaSessionProbe.applies(to:))
            || url.map(TravelokaSessionProbe.applies(to:)) == true
        if shouldScanStorage {
            let scannedJSON = try? await evaluateJavaScriptStringAsync(TravelokaStorageScan.webViewScript)
            context.applyStorageScan(TravelokaStorageScan.parse(json: scannedJSON))
        }
        context.finalizeRoutePrefix()
        return context
    }

    func evaluateJavaScriptStringAsync(_ javaScript: String) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            evaluateJavaScript(javaScript) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let stringResult = result as? String {
                    continuation.resume(returning: stringResult)
                } else if result is NSNull || result == nil {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: result.map { String(describing: $0) })
                }
            }
        }
    }
}
