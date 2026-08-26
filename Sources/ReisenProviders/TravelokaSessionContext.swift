import Foundation

/// Cookie-/Seiten-Kontext für Traveloka-API-POSTs (HAR: `sen_t`, `clientSessionId`, `x-did`).
public struct TravelokaSessionContext: Equatable, Sendable {
    public var deviceId: String?
    public var clientSessionId: String?
    public var sentinelToken: String?
    public var routePrefix: String?
    public var language: String?
    public var country: String?
    public var currency: String?

    public init(
        deviceId: String? = nil,
        clientSessionId: String? = nil,
        sentinelToken: String? = nil,
        routePrefix: String? = nil,
        language: String? = nil,
        country: String? = nil,
        currency: String? = nil
    ) {
        self.deviceId = deviceId
        self.clientSessionId = clientSessionId
        self.sentinelToken = sentinelToken
        self.routePrefix = routePrefix
        self.language = language
        self.country = country
        self.currency = currency
    }

    public var hasSentinel: Bool {
        !(sentinelToken ?? "").isEmpty
    }

    public var resolvedRoutePrefix: String {
        routePrefix ?? TravelokaWebConstants.routePrefix
    }

    public var resolvedLanguage: String {
        nonEmpty(language) ?? localeFromRoute.language
    }

    public var resolvedCountry: String {
        nonEmpty(country) ?? localeFromRoute.country
    }

    public var resolvedCurrency: String {
        nonEmpty(currency) ?? TravelokaWebConstants.defaultCurrency
    }

    private var localeFromRoute: (language: String, country: String) {
        TravelokaLocale.apiLanguageAndCountry(routePrefix: resolvedRoutePrefix)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    public static func from(cookies: [HTTPCookie]) -> TravelokaSessionContext {
        var deviceId: String?
        var clientSessionId: String?
        var sentinelToken: String?
        var language: String?
        var country: String?
        var currency: String?
        for cookie in cookies {
            switch cookie.name {
            case "sen_t":
                sentinelToken = cookie.value
            case "clientSessionId":
                clientSessionId = cookie.value
            case "tv_did", "tvDid", "deviceId":
                if deviceId == nil, Self.isDeviceId(cookie.value) {
                    deviceId = cookie.value
                }
            case "tv_language", "tv-language":
                language = cookie.value
            case "tv_country", "tv-country":
                country = cookie.value
            case "tv_currency", "tv-currency", "currency", "preferred_currency":
                if currency == nil, !cookie.value.isEmpty {
                    currency = cookie.value.uppercased()
                }
            default:
                continue
            }
        }
        return TravelokaSessionContext(
            deviceId: deviceId,
            clientSessionId: clientSessionId,
            sentinelToken: sentinelToken,
            language: language,
            country: country,
            currency: currency
        )
    }

    public mutating func mergingDeviceIdFromStorageScan(_ raw: String?) {
        guard deviceId == nil, let raw, Self.isDeviceId(raw) else { return }
        deviceId = raw
    }

    public mutating func applyPageContext(from url: URL?) {
        guard let url else { return }
        let parts = url.path.split(separator: "/").map(String.init)
        guard let first = parts.first, first.contains("-") else { return }
        routePrefix = first
        if language == nil || country == nil {
            let locale = TravelokaLocale.apiLanguageAndCountry(routePrefix: first)
            if language == nil { language = locale.language }
            if country == nil { country = locale.country }
        }
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
