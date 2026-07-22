import Foundation
import ReisenDomain

public struct ActivityListParser {
    public init() {}

    private static let travelProductKeys: Set<String> = [
        "hotel", "flight", "ferry", "holidayflat", "package"
    ]

    public func parseActivityListHTML(_ html: String) throws -> ParsedActivity {
        // Live-API und HAR liefern JSON mit activities — nicht zwingend HTML mit hrefs.
        // Wenn der Payload wie Activities-JSON aussieht, JSON-Fehler nicht als „keine Links“
        // verschleiern (kein stiller Fallthrough auf HTML-Heuristik).
        if looksLikeActivitiesJSON(html) {
            return try parseActivitiesJSON(from: html)
        }

        let candidateLinks = extractBookingLinks(from: html)
        guard !candidateLinks.isEmpty else {
            throw Check24ParseError.noBookingLinkFound
        }

        let parsedBookings = try candidateLinks.compactMap { link in
            try parseBookingWindow(for: link, in: html)
        }

        if parsedBookings.isEmpty {
            throw Check24ParseError.noBookingDatesFound
        }

        let cancellationDeadlines = (try? parseCancellationDeadlines(from: html)) ?? []
        return ParsedActivity(bookings: parsedBookings, cancellationDeadlines: cancellationDeadlines)
    }

    private func extractBookingLinks(from html: String) -> [String] {
        let pattern = #"href="([^"]+)""#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        guard let regex else { return [] }

        let ns = html as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: html, options: [], range: fullRange)

        let links: [String] = matches.compactMap { match in
            guard match.numberOfRanges >= 2 else { return nil }
            let range = match.range(at: 1)
            guard range.location != NSNotFound else { return nil }
            return ns.substring(with: range)
        }

        return links.filter { href in
            let lower = href.lowercased()
            return lower.contains("booking")
                || lower.contains("buchung")
                || lower.contains("hotel")
                || lower.contains("flug")
                || lower.contains("flight")
                || lower.contains("ferry")
                || lower.contains("faehre")
                || lower.contains("reise")
        }
    }

    private func parseBookingWindow(for href: String, in html: String) throws -> ParsedBooking {
        let ns = html as NSString
        guard html.lowercased().range(of: href.lowercased()) != nil else {
            throw Check24ParseError.activityListNotRecognized
        }
        let nsStart = ns.range(of: href, options: [.caseInsensitive]).location
        guard nsStart != NSNotFound else {
            throw Check24ParseError.activityListNotRecognized
        }

        let snippetStart = nsStart
        let snippetLength = min(600, ns.length - snippetStart)
        let snippet = ns.substring(with: NSRange(location: snippetStart, length: snippetLength))

        let type = bookingType(from: href)
        let dates = try extractDates(from: snippet)
        guard dates.count >= 2 else {
            throw Check24ParseError.noBookingDatesFound
        }

        return ParsedBooking(
            type: type,
            title: extractAnchorText(around: snippet),
            confirmationCode: nil,
            externalUrl: normalizeExternalUrl(href),
            startAt: dates[0],
            endAt: dates[1],
            locationFrom: nil,
            locationTo: nil,
            locationFromAddress: nil,
            locationToAddress: nil,
            status: .unknown,
            details: nil
        )
    }

    private func looksLikeActivitiesJSON(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{" || trimmed.first == "[" else { return false }
        return trimmed.contains("\"activities\"")
    }

    /// Unterstützt:
    /// - Live-API: `{ "activities":[ { startDate, endDate, link, product, detail, ... } ] }`
    /// - HAR/ältere Form: `{ "data":{ "activities":[ { start_date, product_specific_data.booking_uuid, ... } ] } }`
    private func parseActivitiesJSON(from text: String) throws -> ParsedActivity {
        let data = Data(text.utf8)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = json as? [String: Any] else {
            throw Check24ParseError.activityListNotRecognized
        }

        let activities: [[String: Any]]
        if let dataObj = root["data"] as? [String: Any],
           let nested = dataObj["activities"] as? [[String: Any]] {
            activities = nested
        } else if let top = root["activities"] as? [[String: Any]] {
            activities = top
        } else {
            throw Check24ParseError.activityListNotRecognized
        }

        var parsedBookings: [ParsedBooking] = []
        for activity in activities {
            if let booking = parseOneActivityIfRelevant(activity) {
                parsedBookings.append(booking)
            }
        }

        guard !parsedBookings.isEmpty else {
            throw Check24ParseError.noBookingDatesFound
        }

        return ParsedActivity(bookings: parsedBookings, cancellationDeadlines: [])
    }

    /// Nur Reiseprodukte, die nicht storniert/beendet sind und deren Start in der Zukunft liegt.
    private func parseOneActivityIfRelevant(_ activity: [String: Any], now: Date = Date()) -> ParsedBooking? {
        let productKey = productKey(from: activity)
        guard Self.travelProductKeys.contains(productKey) else { return nil }

        let bookingType = mapBookingType(productKey)

        let startRaw = activity["startDate"] as? String
            ?? activity["start_date"] as? String
            ?? (activity["product_specific_data"] as? [String: Any])?["hotel_date_arrival"] as? String
            ?? (activity["productSpecificData"] as? [String: Any])?["hotel_date_arrival"] as? String
        let endRaw = activity["endDate"] as? String
            ?? activity["end_date"] as? String
            ?? (activity["product_specific_data"] as? [String: Any])?["hotel_date_departure"] as? String
            ?? (activity["productSpecificData"] as? [String: Any])?["hotel_date_departure"] as? String

        let startAt: Date? = {
            guard bookingType == .hotel else { return parseFlexibleDate(startRaw) }
            return parseHotelDay(startRaw)
        }()
        let endAt: Date? = {
            guard bookingType == .hotel else { return parseFlexibleDate(endRaw) }
            return parseHotelDay(endRaw)
        }()

        guard let startAt, let endAt else { return nil }


        let statusKey = activityStatusKey(from: activity)
        guard isFutureRelevantBooking(statusKey: statusKey, startAt: startAt, now: now) else {
            return nil
        }

        let externalUrl = activityDetailURL(from: activity)
        let confirmationCode =
            (activity["foreignId"] as? String)
            ?? (activity["foreign_id"] as? String)
            ?? ((activity["product_specific_data"] as? [String: Any])?["booking_number"] as? String)

        let catalogPrice = activityPayment(from: activity)
        let roomInfo = activityRoomInfo(from: activity)

        let details = detailsFromCatalogPrice(
            catalogPrice: catalogPrice,
            roomInfo: roomInfo,
            bookingType: bookingType
        )

        return ParsedBooking(
            type: bookingType,
            title: activityTitle(from: activity),
            confirmationCode: confirmationCode,
            externalUrl: externalUrl,
            startAt: startAt,
            endAt: endAt,
            locationFrom: nil,
            locationTo: activityLocation(from: activity),
            locationFromAddress: nil,
            locationToAddress: activityAddress(from: activity),
            status: mapBookingStatus(statusKey),
            details: details,
            catalogPriceAmount: catalogPrice.amount,
            catalogPriceCurrency: catalogPrice.currency,
            catalogRoomCount: roomInfo.count,
            catalogRoomCategory: roomInfo.category
        )
    }

    /// Hotels: nur Kalenderdatum — Uhrzeit/TZ verwerfen.
    private func parseHotelDay(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return HotelStayDate.parse(raw)
    }

    private func detailsFromCatalogPrice(
        catalogPrice: (amount: Double?, currency: String?),
        roomInfo: (count: Int?, category: String?),
        bookingType: BookingType
    ) -> ParsedBookingDetails? {
        guard let amount = catalogPrice.amount else { return nil }
        let currency = catalogPrice.currency

        let fingerprint = [
            bookingType.rawValue,
            "catalogPrice",
            String(describing: amount),
            String(describing: currency),
            String(describing: roomInfo.count),
            String(describing: roomInfo.category)
        ].joined(separator: "|")

        return ParsedBookingDetails(
            rawDetailsFingerprint: fingerprint,
            totalPriceAmount: amount,
            totalPriceCurrency: currency,
            roomCategory: roomInfo.category,
            boardTypeRaw: nil,
            includedBreakfast: nil,
            guestCount: nil,
            roomCount: roomInfo.count,
            airline: nil,
            passengerCount: nil,
            baggageInfoRaw: nil
        )
    }

    private func activityPayment(from activity: [String: Any]) -> (amount: Double?, currency: String?) {
        guard let payment = activity["payment"] as? [String: Any] else {
            return (nil, nil)
        }

        let amount: Double?
        if let number = payment["amount"] as? Double {
            amount = number
        } else if let number = payment["amount"] as? Int {
            amount = Double(number)
        } else if let text = payment["amount"] as? String {
            amount = parseGermanOrEnglishAmount(text)
        } else {
            amount = nil
        }

        let currency: String?
        if let suffix = payment["suffix"] as? String, suffix.contains("€") {
            currency = "EUR"
        } else if amount != nil {
            currency = "EUR"
        } else {
            currency = nil
        }

        return (amount, currency)
    }

    private func activityRoomInfo(from activity: [String: Any]) -> (count: Int?, category: String?) {
        let psd = (activity["product_specific_data"] as? [String: Any])
            ?? (activity["productSpecificData"] as? [String: Any])
            ?? [:]
        let raw = (psd["sso_room_text"] as? String)
            ?? (psd["ssoRoomText"] as? String)
            ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, nil) }

        // „1 Doppelzimmer mit Terrasse“ / „2x Suite“
        guard let regex = try? NSRegularExpression(
            pattern: #"^(\d+)\s*x?\s*(.+)$"#,
            options: [.caseInsensitive]
        ) else {
            return (nil, trimmed)
        }
        let ns = trimmed as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: full),
              match.numberOfRanges == 3 else {
            return (1, trimmed)
        }
        let count = Int(ns.substring(with: match.range(at: 1)))
        let category = ns.substring(with: match.range(at: 2))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (count, category.isEmpty ? nil : category)
    }

    private func parseGermanOrEnglishAmount(_ raw: String) -> Double? {
        let cleaned = raw
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "EUR", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let lastComma = cleaned.lastIndex(of: ",")
        let lastDot = cleaned.lastIndex(of: ".")
        let decimalSeparator: Character = {
            if let comma = lastComma, let dot = lastDot {
                return comma > dot ? "," : "."
            }
            if lastComma != nil { return "," }
            return "."
        }()
        let thousandSeparator: Character = decimalSeparator == "," ? "." : ","
        let normalized = cleaned
            .replacingOccurrences(of: String(thousandSeparator), with: "")
            .replacingOccurrences(of: String(decimalSeparator), with: ".")
        return Double(normalized)
    }

    private func activityStatusKey(from activity: [String: Any]) -> String {
        if let status = activity["status"] as? [String: Any],
           let key = status["key"] as? String {
            return key.lowercased()
        }
        return ""
    }

    private func mapBookingStatus(_ statusKey: String) -> BookingStatus {
        switch statusKey {
        case "cancelled", "canceled", "terminated":
            return .cancelled
        case "upcoming", "active":
            return .confirmed
        default:
            return .unknown
        }
    }

    /// Vergangene (`ended`) und stornierte Buchungen aus; Start muss ab heute liegen.
    private func isFutureRelevantBooking(statusKey: String, startAt: Date, now: Date) -> Bool {
        switch statusKey {
        case "cancelled", "canceled", "terminated", "ended":
            return false
        default:
            break
        }
        let startOfToday = Calendar.current.startOfDay(for: now)
        return startAt >= startOfToday
    }

    private func productKey(from activity: [String: Any]) -> String {
        if let product = activity["product"] as? [String: Any] {
            if let key = product["key"] as? String { return key.lowercased() }
        }
        return ""
    }

    private func mapBookingType(_ productKey: String) -> BookingType {
        switch productKey {
        case "hotel", "holidayflat", "package":
            return .hotel
        case "flight":
            return .flight
        case "ferry":
            return .ferry
        default:
            return .other
        }
    }

    private func activityTitle(from activity: [String: Any]) -> String? {
        if let detail = activity["detail"] as? [String: Any],
           let line1 = detail["line1"] as? String,
           !line1.isEmpty {
            return line1
        }
        let psd = (activity["product_specific_data"] as? [String: Any])
            ?? (activity["productSpecificData"] as? [String: Any])
            ?? [:]
        if let hotelName = psd["hotel_name"] as? String, !hotelName.isEmpty {
            return hotelName
        }
        return nil
    }

    private func activityLocation(from activity: [String: Any]) -> String? {
        if let detail = activity["detail"] as? [String: Any],
           let line2 = detail["line2"] as? String,
           !line2.isEmpty,
           !line2.lowercased().contains("gebucht am") {
            return line2
        }
        let psd = (activity["product_specific_data"] as? [String: Any])
            ?? (activity["productSpecificData"] as? [String: Any])
            ?? [:]
        return psd["hotel_city_name"] as? String
    }

    private func activityAddress(from activity: [String: Any]) -> String? {
        let psd = (activity["product_specific_data"] as? [String: Any])
            ?? (activity["productSpecificData"] as? [String: Any])
            ?? [:]

        let street = psd["hotel_street"] as? String
        let postalCode = psd["hotel_zipcode"] as? String
        let city = psd["hotel_city_name"] as? String
        let country = psd["hotel_country_name"] as? String

        let nonEmpty = { (s: String?) -> String? in
            guard let s, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let streetPart = nonEmpty(street)
        let cityPart: String? = {
            let c = nonEmpty(city)
            let z = nonEmpty(postalCode)
            switch (c, z) {
            case let (c?, z?): return "\(z) \(c)"
            case let (c?, nil): return c
            case let (nil, z?): return z
            default: return nil
            }
        }()
        let countryPart = nonEmpty(country)

        let parts = [streetPart, cityPart, countryPart].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }

    private func activityDetailURL(from activity: [String: Any]) -> String? {
        // Live-API: link.link oder travelInformation.buttons.desktop[0].url
        if let linkObj = activity["link"] as? [String: Any],
           let link = linkObj["link"] as? String,
           !link.isEmpty {
            return normalizeBookingDetailURL(link)
        }

        if let travel = activity["travelInformation"] as? [String: Any],
           let buttons = travel["buttons"] as? [String: Any],
           let desktop = buttons["desktop"] as? [[String: Any]],
           let url = desktop.first?["url"] as? String {
            return normalizeBookingDetailURL(url)
        }

        // HAR: product_specific_data.booking_uuid
        let psd = (activity["product_specific_data"] as? [String: Any])
            ?? (activity["productSpecificData"] as? [String: Any])
            ?? [:]
        if let uuid = psd["booking_uuid"] as? String, !uuid.isEmpty {
            return "https://hotel.check24.de/kundenbereich/buchung/\(uuid)"
        }
        if let uuid = activity["booking_uuid"] as? String, !uuid.isEmpty {
            return "https://hotel.check24.de/kundenbereich/buchung/\(uuid)"
        }
        return nil
    }

    /// Mobile/UL-Links auf stabile Desktop-Buchungs-URLs normalisieren.
    private func normalizeBookingDetailURL(_ raw: String) -> String {
        var urlString = raw
        if let q = urlString.firstIndex(of: "?") {
            urlString = String(urlString[..<q])
        }

        if let uuid = extractUUID(from: urlString),
           urlString.lowercased().contains("hotel"),
           urlString.lowercased().contains("buchung") {
            return "https://hotel.check24.de/kundenbereich/buchung/\(uuid)"
        }

        // m.hotel.../ul/... → hotel.../...
        urlString = urlString
            .replacingOccurrences(of: "https://m.hotel.check24.de/ul/", with: "https://hotel.check24.de/")
            .replacingOccurrences(of: "http://m.hotel.check24.de/ul/", with: "https://hotel.check24.de/")

        return urlString
    }

    private func extractUUID(from text: String) -> String? {
        let pattern = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return ns.substring(with: match.range)
    }

    private func parseFlexibleDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }

        // ISO-ähnlich: 2026-08-11T23:59:00
        let candidates = [raw, raw.replacingOccurrences(of: "T", with: " ")]
        let isoFormats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        let iso = DateFormatter()
        iso.locale = Locale(identifier: "en_US_POSIX")
        // Activities-API liefert viele ISO-Zeitstempel ohne expliziten Offset.
        // Für die korrekte Ortszeit-Ausgabe formatieren wir später (UI) anhand der Hotel-Ortszeit.
        // Daher: zunächst als UTC interpretieren.
        iso.timeZone = TimeZone(secondsFromGMT: 0)
        for format in isoFormats {
            iso.dateFormat = format
            for candidate in candidates {
                if let date = iso.date(from: candidate) { return date }
            }
        }

        // HAR GMT: Tue Aug 11 2026 23:59:00 GMT+0200
        return parseHarGmtDate(raw)
    }

    private func parseHarGmtDate(_ s: String) -> Date? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT'Z"
        return df.date(from: s)
    }

    private func bookingType(from href: String) -> BookingType {
        let lower = href.lowercased()
        if lower.contains("hotel") || lower.contains("ferienwohnung") { return .hotel }
        if lower.contains("flug") || lower.contains("flight") { return .flight }
        if lower.contains("ferry") || lower.contains("faehre") { return .ferry }
        return .other
    }

    private func extractDates(from snippet: String) throws -> [Date] {
        let pattern = #"\b(\d{2})\.(\d{2})\.(\d{4})\b"#
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let ns = snippet as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: snippet, options: [], range: fullRange)

        if matches.isEmpty {
            throw Check24ParseError.noBookingDatesFound
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE_POSIX")
        formatter.dateFormat = "dd.MM.yyyy"

        return matches.compactMap { match in
            let full = ns.substring(with: match.range(at: 0))
            return formatter.date(from: full)
        }
    }

    private func extractAnchorText(around snippet: String) -> String? {
        let pattern = #">([^<]{1,80})</a>"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        guard let regex else { return nil }
        let ns = snippet as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: snippet, options: [], range: fullRange) else { return nil }
        guard match.numberOfRanges >= 2 else { return nil }
        let range = match.range(at: 1)
        guard range.location != NSNotFound else { return nil }
        return ns.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseCancellationDeadlines(from html: String) throws -> [ParsedCancellationDeadline] {
        let ns = html as NSString
        let pattern = #"(?is)storn[^\d]{0,120}((\d{2})\.(\d{2})\.(\d{4}))"#
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let fullRange = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: html, options: [], range: fullRange)

        if matches.isEmpty {
            throw Check24ParseError.noCancellationDeadlineFound
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE_POSIX")
        formatter.dateFormat = "dd.MM.yyyy"

        return matches.compactMap { match in
            guard match.numberOfRanges >= 2 else { return nil }
            let dateString = ns.substring(with: match.range(at: 1))
            guard let date = formatter.date(from: dateString) else { return nil }
            return ParsedCancellationDeadline(
                deadlineAt: date,
                policyText: nil,
                isStrict: true,
                isFreeCancellation: false,
                hotelOffsetSeconds: nil,
                cancellationFeeAmount: nil
            )
        }
    }

    private func normalizeExternalUrl(_ href: String) -> String? {
        if href.starts(with: "http://") || href.starts(with: "https://") {
            return normalizeBookingDetailURL(href)
        }
        if href.starts(with: "/") {
            return "https://kundenbereich.check24.de" + href
        }
        return nil
    }
}
