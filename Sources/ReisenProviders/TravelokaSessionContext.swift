import Foundation

/// Cookie-/Seiten-Kontext für Traveloka-API-POSTs (HAR: `sen_t`, `clientSessionId`, `x-did`).
public struct TravelokaSessionContext: Equatable, Sendable {
    public var deviceId: String?
    public var mccId: String?
    public var clientSessionId: String?
    public var sentinelToken: String?
    public var currency: String?
    /// Nutzerseite für API-Referer (HAR: aktuelle Seite, nicht immer mybooking).
    public var bestPageURL: URL?

    public init(
        deviceId: String? = nil,
        mccId: String? = nil,
        clientSessionId: String? = nil,
        sentinelToken: String? = nil,
        currency: String? = nil,
        bestPageURL: URL? = nil
    ) {
        self.deviceId = deviceId
        self.mccId = mccId
        self.clientSessionId = clientSessionId
        self.sentinelToken = sentinelToken
        self.currency = currency
        self.bestPageURL = bestPageURL
    }

    public var hasSentinel: Bool {
        !(sentinelToken ?? "").isEmpty
    }

    /// Sync pinnt immer die kanonische EN-Locale; Session-Cookies/URLs ändern sie nicht.
    public var resolvedRoutePrefix: String {
        TravelokaWebConstants.routePrefix
    }

    public var resolvedLanguage: String {
        TravelokaWebConstants.defaultLanguage
    }

    public var resolvedCountry: String {
        TravelokaWebConstants.defaultCountry
    }

    public var resolvedCurrency: String {
        nonEmpty(currency) ?? TravelokaWebConstants.defaultCurrency
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    public static func from(cookies: [HTTPCookie]) -> TravelokaSessionContext {
        var deviceId: String?
        var mccId: String?
        var clientSessionId: String?
        var sentinelToken: String?
        var currency: String?
        for cookie in cookies {
            switch cookie.name {
            case "sen_t":
                sentinelToken = cookie.value
            case "tv_mcc_id":
                if mccId == nil, Self.isDeviceId(cookie.value) {
                    mccId = cookie.value
                }
            case "clientSessionId":
                clientSessionId = cookie.value
            case "tv_did", "tvDid", "deviceId":
                if deviceId == nil, Self.isDeviceId(cookie.value) {
                    deviceId = cookie.value
                }
            case "tv_currency", "tv-currency", "currency", "preferred_currency", "selectedCurrency":
                if currency == nil, !cookie.value.isEmpty {
                    currency = cookie.value.uppercased()
                }
            default:
                continue
            }
        }
        return TravelokaSessionContext(
            deviceId: deviceId,
            mccId: mccId,
            clientSessionId: clientSessionId,
            sentinelToken: sentinelToken,
            currency: currency
        )
    }

    public mutating func mergingDeviceIdFromStorageScan(_ raw: String?) {
        guard deviceId == nil, let raw, Self.isDeviceId(raw) else { return }
        deviceId = raw
    }

    public mutating func applyPageContext(from url: URL?) {
        guard let url else { return }
        applyNavigationHints(from: [url])
    }

    /// Locale/Referer aus beliebigen Navigations-URLs (aktuell, Verlauf, Hub-lastURL).
    public mutating func applyNavigationHints(from urls: [URL]) {
        var bestReferer: URL?
        var bestRefererScore = Int.min

        for (index, url) in urls.enumerated() {
            guard TravelokaSessionProbe.applies(to: url) else { continue }

            guard Self.isUserFacingPage(url) else { continue }
            let score = Self.refererScore(for: url, hintIndex: index)
            if score > bestRefererScore {
                bestRefererScore = score
                bestReferer = url
            }
        }

        bestPageURL = bestReferer
    }

    /// Höher = besserer API-Referer (lokalisierte Detail-/Account-Seiten vor Homepage).
    static func refererScore(for url: URL, hintIndex: Int) -> Int {
        var score = hintIndex
        if let prefix = TravelokaRoutePrefix.extract(from: url) {
            score += 100
            let path = url.path.lowercased()
            if path.contains("/item/details/") {
                score += 50
            } else if path.contains("/user/mybooking") {
                score += 40
            } else if path.contains("/user/signin") {
                score += 20
            }
        }
        return score
    }

    public mutating func applyStorageScan(_ scan: TravelokaStorageScan) {
        mergingDeviceIdFromStorageScan(scan.deviceId)
    }

    /// Referer für Traveloka-API-POSTs (HAR: aktuelle Nutzerseite, sonst mybooking).
    /// Locale-Prefix wird auf `resolvedRoutePrefix` normalisiert (Header/Referer-Konsistenz).
    public func apiReferer() -> String {
        if let bestPageURL, Self.isUserFacingPage(bestPageURL) {
            return Self.canonicalUserPageURL(bestPageURL).absoluteString
        }
        return "\(TravelokaWebConstants.origin)/\(resolvedRoutePrefix)/user/mybooking"
    }

    static func canonicalUserPageURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var parts = components.path
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
        if let first = parts.first, TravelokaRoutePrefix.isValid(first) {
            parts[0] = TravelokaWebConstants.routePrefix
        } else {
            parts.insert(TravelokaWebConstants.routePrefix, at: 0)
        }
        components.path = "/" + parts.joined(separator: "/")
        return components.url ?? url
    }

    public static func isUserFacingPage(_ url: URL) -> Bool {
        guard TravelokaSessionProbe.applies(to: url) else { return false }
        return !url.path.contains("/api/")
    }

    public var xDidHeaderValue: String? {
        guard let deviceId, Self.isDeviceId(deviceId) else { return nil }
        return Data(deviceId.utf8).base64EncodedString()
    }

    public func applying(to headers: [String: String]) -> [String: String] {
        var next = headers
        if let clientSessionId, !clientSessionId.isEmpty {
            next["tv-clientsessionid"] = clientSessionId
        }
        if let xDidHeaderValue {
            next["x-did"] = xDidHeaderValue
        }
        if let mccId, Self.isDeviceId(mccId) {
            next["tv-mcc-id"] = mccId
        }
        next["tv-language"] = resolvedLanguage
        next["tv-country"] = resolvedCountry
        next["tv-currency"] = resolvedCurrency
        next["x-route-prefix"] = resolvedRoutePrefix
        return next
    }

    public func withSentinel(in payload: [String: Any]) -> [String: Any] {
        guard hasSentinel, let sentinelToken else { return payload }
        var next = payload
        next["sentinel"] = [
            "token": sentinelToken,
            "signals": [] as [Any],
        ]
        return next
    }

    public static func isDeviceId(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 26, trimmed.hasPrefix("01") else { return false }
        let alphabet = CharacterSet(charactersIn: "0123456789ABCDEFGHJKMNPQRSTVWXYZ")
        return trimmed.uppercased().unicodeScalars.allSatisfy { alphabet.contains($0) }
    }
}
