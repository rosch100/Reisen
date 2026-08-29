import Foundation
import ReisenDomain

enum TravelokaJSON {
    static func object(from text: String) throws -> [String: Any] {
        guard let data = text.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw TravelokaProviderError.invalidResponse
        }
        return root
    }

    static func dataObject(from root: [String: Any]) -> [String: Any]? {
        root["data"] as? [String: Any]
    }

    static func itineraryEntries(from responseText: String) throws -> [[String: Any]] {
        let root = try object(from: responseText)
        guard let data = dataObject(from: root),
              let entries = data["itineraryEntryList"] as? [[String: Any]]
        else {
            throw TravelokaProviderError.invalidResponse
        }
        return entries
    }

    static func firstItineraryEntry(from responseText: String) throws -> [String: Any] {
        let entries = try itineraryEntries(from: responseText)
        guard let entry = entries.first else {
            throw TravelokaProviderError.invalidResponse
        }
        return entry
    }

    static func cardSummary(from entry: [String: Any]) -> [String: Any] {
        (entry["cardSummaryInfo"] as? [String: Any]) ?? [:]
    }

    static func cardDetail(from entry: [String: Any]) -> [String: Any] {
        (entry["cardDetailInfo"] as? [String: Any]) ?? [:]
    }

    static func commonSummary(from entry: [String: Any]) -> [String: Any] {
        let summary = cardSummary(from: entry)
        return (summary["commonSummary"] as? [String: Any]) ?? [:]
    }

    static func dictionary(_ value: Any?) -> [String: Any] {
        (value as? [String: Any]) ?? [:]
    }

    static func string(fromKeys keys: [String], in dict: [String: Any]) -> String? {
        string(fromKeys: keys, in: [dict])
    }

    static func string(fromKeys keys: [String], in dicts: [[String: Any]]) -> String? {
        string(value(fromKeys: keys, in: dicts))
    }

    static func value(fromKeys keys: [String], in dicts: [[String: Any]]) -> Any? {
        for dict in dicts {
            for key in keys {
                guard let value = dict[key], !(value is NSNull) else { continue }
                return value
            }
        }
        return nil
    }

    static func firstString(_ values: [Any?]) -> String? {
        for value in values {
            if let text = string(value) {
                return text
            }
        }
        return nil
    }

    static func firstDictionary(_ values: [Any?]) -> [String: Any] {
        for value in values {
            let dict = dictionary(value)
            if !dict.isEmpty { return dict }
        }
        return [:]
    }

    static func strings(_ value: Any?) -> [String] {
        value as? [String] ?? []
    }

    static func hotelVoucher(from entry: [String: Any], hotelDetail: [String: Any]) -> [String: Any] {
        let fromDetail = dictionary(hotelDetail["voucherInfo"])
        if !fromDetail.isEmpty {
            return fromDetail
        }
        return dictionary(dictionary(entry["hotelVoucherInfo"])["voucherInfo"])
    }

    static func localeAwareInfo(from voucher: [String: Any]) -> [String: Any] {
        let list = voucher["localeAwareInfos"] as? [[String: Any]] ?? []
        let locales = list.compactMap { string($0["locale"]) }
        guard let key = preferredLocaleMapKey(from: locales) else {
            return list.first ?? [:]
        }
        return list.first(where: { string($0["locale"]) == key }) ?? list.first ?? [:]
    }

    static func translatedCity(from localeInfo: [String: Any]) -> String? {
        string(dictionary(dictionary(localeInfo["translatedData"])["address"])["city"])
    }

    static func string(_ value: Any?) -> String? {
        if let s = value as? String {
            return NonEmpty.string(s)
        }
        if let n = value as? NSNumber {
            return n.stringValue
        }
        return nil
    }

    static func int(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String, let i = Int(s) { return i }
        return nil
    }

    static func double(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String, let d = Double(s) { return d }
        return nil
    }

    static func bool(_ value: Any?) -> Bool? {
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        if let s = value as? String {
            switch s.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return nil
            }
        }
        return nil
    }

    static func dateFromMillis(_ value: Any?) -> Date? {
        guard let millis = double(value) else { return nil }
        return Date(timeIntervalSince1970: millis / 1000.0)
    }

    static func dayComponents(_ value: Any?) -> (year: Int, month: Int, day: Int)? {
        guard let dict = value as? [String: Any],
              let y = int(dict["year"]),
              let m = int(dict["month"]),
              let d = int(dict["day"])
        else {
            return nil
        }
        return (y, m, d)
    }

    /// `"14:00"` oder `{ "hour": "9", "minute": "0" }`.
    static func minutesFromTime(_ value: Any?) -> Int? {
        if let fromString = ClockTime.minutes(fromHHMM: string(value)) {
            return fromString
        }
        let parts = dictionary(value)
        guard let hour = int(parts["hour"]) else { return nil }
        return ClockTime.minutes(hours: hour, minute: int(parts["minute"]) ?? 0)
    }

    static func dateFromDay(
        _ day: (year: Int, month: Int, day: Int),
        minutes: Int?,
        timeZone: TimeZone
    ) -> Date? {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = timeZone
        components.year = day.year
        components.month = day.month
        components.day = day.day
        if let minutes {
            components.hour = minutes / 60
            components.minute = minutes % 60
        } else {
            components.hour = 0
            components.minute = 0
        }
        return components.date
    }

    static func timeZone(iana: String?) -> TimeZone? {
        guard let raw = string(iana) else { return nil }
        if let tz = TimeZone(identifier: raw) {
            return tz
        }
        return timeZone(fromGMTOffset: raw)
    }

    /// Traveloka Vehicle liefert oft Offset statt IANA (`+07:00`, `UTC+07:00`).
    static func timeZone(fromGMTOffset raw: String) -> TimeZone? {
        guard let trimmed = NonEmpty.string(raw),
              let regex = gmtOffsetRegex,
              let match = regex.firstMatch(
                  in: trimmed,
                  range: NSRange(location: 0, length: (trimmed as NSString).length)
              ),
              match.numberOfRanges >= 3
        else {
            return nil
        }
        let ns = trimmed as NSString
        let sign = ns.substring(with: match.range(at: 1)) == "-" ? -1 : 1
        let hours = Int(ns.substring(with: match.range(at: 2))) ?? 0
        var minutes = 0
        if match.range(at: 3).location != NSNotFound {
            minutes = Int(ns.substring(with: match.range(at: 3))) ?? 0
        }
        return TimeZone(secondsFromGMT: sign * (hours * 3600 + minutes * 60))
    }

    /// Traveloka-Geldwerte: `amount` ist Integer-String, Dezimalstellen in `numOfDecimalPoint` (`437` + `2` → `4.37`).
    static func scaledAmount(amount: Any?, decimalPoint: Any?) -> Double? {
        guard let raw = double(amount) else { return nil }
        if let text = string(amount), text.contains(".") {
            return raw
        }
        let decimals = int(decimalPoint) ?? 0
        guard decimals > 0 else { return raw }
        return raw / pow(10.0, Double(decimals))
    }

    /// SSOT für Fee- und `expectedAmount`-Objekte (`currencyValue` + `numOfDecimalPoint`).
    static func money(from value: [String: Any]?) -> (amount: Double, currency: String?)? {
        guard let value, !value.isEmpty else { return nil }
        let currencyValue = dictionary(value["currencyValue"])
        guard let amount = scaledAmount(
            amount: currencyValue["amount"] ?? value["amount"],
            decimalPoint: value["numOfDecimalPoint"] ?? currencyValue["numOfDecimalPoint"]
        ) else {
            return nil
        }
        return (amount, string(currencyValue["currency"] ?? value["currency"]))
    }

    static func moneyAmount(from value: [String: Any]?) -> Double? {
        money(from: value)?.amount
    }

    /// Buchungspreis aus `paymentInfo.expectedAmount`; `nil` wenn versteckt oder fehlend.
    static func bookingMoney(from entry: [String: Any]) -> (amount: Double, currency: String?)? {
        let payment = dictionary(entry["paymentInfo"])
        if bool(payment["isTotalPriceHidden"]) == true
            || bool(payment["totalPriceHidden"]) == true
        {
            return nil
        }
        return money(from: dictionary(payment["expectedAmount"]))
    }

    static func bookingRateDetails(from entry: [String: Any]) -> BookingRateDetails? {
        guard let money = bookingMoney(from: entry) else { return nil }
        return BookingRateDetails(
            totalPriceAmount: money.amount,
            totalPriceCurrency: money.currency
        )
    }

    static func dateFromApplied(_ value: Any?, timeZone: TimeZone) -> Date? {
        let dict = dictionary(value)
        guard let day = dayComponents(dict["monthDayYear"]) else { return nil }
        return dateFromDay(day, minutes: minutesFromTime(dict["hourMinute"]), timeZone: timeZone)
    }

    /// Locale-Map (`en_EN` → Objekt) oder bereits das Detail-Objekt.
    static func localizedMapValue(_ value: Any?) -> [String: Any] {
        let dict = dictionary(value)
        if dict.isEmpty { return [:] }
        if isFlightDetailObject(dict) {
            return dict
        }
        guard let key = preferredLocaleMapKey(from: Array(dict.keys)) else { return [:] }
        return dictionary(dict[key])
    }

    /// `en*` zuerst (sortiert), sonst erste sortierte Locale-Taste.
    static func preferredLocaleMapKey(from keys: [String]) -> String? {
        let sorted = keys.sorted()
        return sorted.first(where: isEnglishLocale) ?? sorted.first
    }

    static func flightBookingDetail(from entry: [String: Any]) -> [String: Any] {
        dictionary(dictionary(dictionary(entry["bookingInfo"])["flightBookingInfo"])["bookingDetail"])
    }

    /// Segmente aus `segments`, sonst `routes` / `flightRouteGroups`, sonst E-Ticket.
    static func flightSegments(
        bookingDetail: [String: Any],
        eTicket: [String: Any]
    ) -> [[String: Any]] {
        firstNonEmpty(
            dictionaries(bookingDetail["segments"]) ?? [],
            flattenedRouteSegments(bookingDetail["routes"]),
            flattenedRouteGroups(bookingDetail["flightRouteGroups"]),
            dictionaries(eTicket["segments"]) ?? []
        )
    }

    static func flightAirport(from segment: [String: Any], isOrigin: Bool) -> [String: Any] {
        let nested = dictionary(segment[isOrigin ? "sourceAirport" : "destinationAirport"])
        if hasAirportIdentity(nested) {
            return nested
        }
        let alt = dictionary(segment[isOrigin ? "departureAirport" : "arrivalAirport"])
        return airportFields(
            code: string(fromKeys: isOrigin ? ["departureCityCode"] : ["arrivalCityCode"], in: segment)
                ?? string(fromKeys: ["airportId", "airportCode"], in: alt),
            city: string(fromKeys: isOrigin ? ["departureCity"] : ["arrivalCity"], in: segment)
                ?? string(fromKeys: ["city", "location"], in: alt),
            name: string(fromKeys: ["airportName", "name"], in: alt)
        )
    }

    private static func isEnglishLocale(_ key: String) -> Bool {
        key.lowercased().hasPrefix("en")
    }

    private static func isFlightDetailObject(_ dict: [String: Any]) -> Bool {
        dict["segments"] != nil || dict["passengers"] != nil || dict["pnrCode"] != nil
    }

    private static func hasAirportIdentity(_ airport: [String: Any]) -> Bool {
        string(airport["airportCode"]) != nil
            || string(airport["location"]) != nil
            || string(airport["airportName"]) != nil
    }

    private static func airportFields(code: String?, city: String?, name: String?) -> [String: Any] {
        var result: [String: Any] = [:]
        if let code { result["airportCode"] = code }
        if let city { result["location"] = city }
        if let name { result["airportName"] = name }
        return result
    }

    private static func dictionaries(_ value: Any?) -> [[String: Any]]? {
        value as? [[String: Any]]
    }

    private static func firstNonEmpty(_ candidates: [[String: Any]]...) -> [[String: Any]] {
        candidates.first(where: { !$0.isEmpty }) ?? []
    }

    private static func flattenedRouteSegments(_ value: Any?) -> [[String: Any]] {
        (dictionaries(value) ?? []).flatMap { route -> [[String: Any]] in
            if let nested = dictionaries(route["segments"]), !nested.isEmpty {
                return nested
            }
            return looksLikeFlightSegment(route) ? [route] : []
        }
    }

    private static func flattenedRouteGroups(_ value: Any?) -> [[String: Any]] {
        (dictionaries(value) ?? []).flatMap { flattenedRouteSegments($0["routes"]) }
    }

    private static func looksLikeFlightSegment(_ route: [String: Any]) -> Bool {
        route["sourceAirport"] != nil
            || route["departureCity"] != nil
            || route["departureDateTime"] != nil
    }

    private static let gmtOffsetRegex = try? NSRegularExpression(
        pattern: #"^(?:UTC|GMT)?\s*([+-])(\d{1,2})(?::?(\d{2}))?$"#,
        options: [.caseInsensitive]
    )

    /// Lokale Traveloka-Deadline-/Slot-Strings (`2026-09-06T23:59:00`).
    static func localDateTime(_ value: String, timeZone: TimeZone) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
            "dd-MMM-yyyy HH:mm",
            "dd-MMM-yyyy HH:mm:ss",
            "dd MMM yyyy HH:mm",
        ]
        for format in formats {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = timeZone
            df.dateFormat = format
            if let date = df.date(from: value) {
                return date
            }
        }
        return nil
    }
}
