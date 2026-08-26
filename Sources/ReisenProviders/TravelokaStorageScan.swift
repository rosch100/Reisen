import Foundation

/// Geräte-ID aus Web Storage (WKWebView-Scan). Sync-Locale kommt nicht aus Storage.
public struct TravelokaStorageScan: Equatable, Sendable {
    public var deviceId: String?

    public init(deviceId: String? = nil) {
        self.deviceId = deviceId
    }

    public static func parse(json: String?) -> TravelokaStorageScan {
        guard let json,
              let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return TravelokaStorageScan()
        }
        let deviceId = (root["deviceId"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return TravelokaStorageScan(
            deviceId: TravelokaSessionContext.isDeviceId(deviceId ?? "") ? deviceId : nil
        )
    }

    /// Liest Device-ID aus localStorage/sessionStorage.
    public static let webViewScript = """
    (() => {
      const isId = (v) => typeof v === 'string' && /^01[0-9A-HJKMNP-TV-Z]{24}$/i.test(v.trim());
      const result = { deviceId: null };

      const deviceKeys = ['tvlk_device_id', 'tv_device_id', 'deviceId', 'tvDid', 'DID'];
      for (const k of deviceKeys) {
        const a = localStorage.getItem(k);
        if (isId(a)) { result.deviceId = a.trim(); break; }
        const b = sessionStorage.getItem(k);
        if (isId(b)) { result.deviceId = b.trim(); break; }
      }

      if (!result.deviceId) {
        for (const store of [localStorage, sessionStorage]) {
          for (let i = 0; i < store.length; i++) {
            const k = store.key(i);
            if (!k) continue;
            const v = store.getItem(k);
            if (isId(v)) { result.deviceId = v.trim(); break; }
            try {
              const o = JSON.parse(v);
              if (o && isId(o.deviceId)) { result.deviceId = o.deviceId.trim(); break; }
              if (o && isId(o.did)) { result.deviceId = o.did.trim(); break; }
            } catch (e) {}
          }
          if (result.deviceId) break;
        }
      }

      return JSON.stringify(result);
    })()
    """
}
