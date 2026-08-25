import Foundation
import WebKit

extension WKWebView {
    /// Liest Traveloka-Session-Kontext aus Cookies (+ optional Device-ID aus Web Storage).
    public func travelokaSessionContext() async -> TravelokaSessionContext {
        var context = TravelokaSessionContext.from(cookies: await allHTTPCookies())
        context.applyPageContext(from: url)
        if context.deviceId == nil {
            let scanned = try? await evaluateJavaScriptStringAsync(Self.travelokaDeviceIdScanScript)
            context.mergingDeviceIdFromStorageScan(scanned)
        }
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

    private static let travelokaDeviceIdScanScript = """
    (() => {
      const isId = (v) => typeof v === 'string' && /^01[0-9A-HJKMNP-TV-Z]{24}$/i.test(v.trim());
      const keys = ['tvlk_device_id', 'tv_device_id', 'deviceId', 'tvDid', 'DID'];
      for (const k of keys) {
        const a = localStorage.getItem(k);
        if (isId(a)) return a.trim();
        const b = sessionStorage.getItem(k);
        if (isId(b)) return b.trim();
      }
      for (const store of [localStorage, sessionStorage]) {
        for (let i = 0; i < store.length; i++) {
          const k = store.key(i);
          if (!k) continue;
          const v = store.getItem(k);
          if (isId(v)) return v.trim();
          try {
            const o = JSON.parse(v);
            if (o && isId(o.deviceId)) return o.deviceId.trim();
            if (o && isId(o.did)) return o.did.trim();
          } catch (e) {}
        }
      }
      return null;
    })()
    """
}
