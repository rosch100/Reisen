import Foundation
import ReisenDomain

enum ExpediaEnrichmentParser {
    private static func facts(
        fromTripItemData data: [String: Any],
        bookingType: BookingType,
        externalUrl: String,
        cancellationUrl: String?
    ) -> ProviderBookingFacts {
        let root = data["trip"] ?? data
        let valueTexts = ExpediaJSON.collectStrings(key: "value", in: root, limit: 60)
        let texts = ExpediaJSON.collectStrings(key: "primary", in: root, limit: 120)
            + ExpediaJSON.collectStrings(key: "text", in: root, limit: 80)
            + ExpediaJSON.collectStrings(key: "stylizedText", in: root, limit: 40)
            + valueTexts

        let confirmation = texts.compactMap(parseConfirmation(from:)).first
        let operatorName = parseOperator(from: texts, bookingType: bookingType)
        let price = texts.compactMap { ExpediaJSON.parseEuroAmount($0) }.first
        let rateDetails = price.map {
            BookingRateDetails(
                totalPriceAmount: NSDecimalNumber(decimal: $0.0).doubleValue,
                totalPriceCurrency: $0.1
            )
        }
        let schedule = ExpediaScheduleParser.window(fromSecondaryTexts: texts, bookingType: bookingType)
        let location = parseLocation(from: texts, bookingType: bookingType)
        let cancelFromBody = valueTexts.first(where: looksLikeLodgingCancelURL)

        return ProviderBookingFacts(
            provider: .expedia,
            bookingType: bookingType,
            start: schedule?.start,
            end: schedule?.end,
            title: ExpediaJSON.firstString(keys: ["primary"], in: ExpediaJSON.dict(root) ?? [:]),
            confirmationCode: confirmation,
            externalUrl: externalUrl,
            cancellationUrl: cancellationUrl ?? cancelFromBody,
            locationFrom: location.from,
            locationTo: location.to,
            operatorName: operatorName,
            statusRaw: confirmedStatusRaw(from: texts),
            rateDetails: rateDetails,
            hotelCheckInMinutes: schedule?.hotelCheckInMinutes,
            hotelCheckOutMinutes: schedule?.hotelCheckOutMinutes,
            rawPayloadFingerprint: nil
        )
    }

    static func enrichment(
        fromTripItemData data: [String: Any],
        bookingType: BookingType,
        externalUrl: String,
        cancellationUrl: String?
    ) -> ProviderBookingEnrichment {
        DraftAssembler.enrichment(
            from: facts(
                fromTripItemData: data,
                bookingType: bookingType,
                externalUrl: externalUrl,
                cancellationUrl: cancellationUrl
            )
        )
    }

    static func hotelCancellationURL(fromServicingData data: [String: Any]) -> String? {
        let urls = ExpediaJSON.collectStrings(key: "value", in: data, limit: 80)
            + ExpediaJSON.collectStrings(key: "url", in: data, limit: 40)
        return urls.first(where: looksLikeLodgingCancelURL)
    }

    static func cancellationDeadlines(fromRoomDetails data: [String: Any]) -> [CancellationDeadline] {
        let texts = ExpediaJSON.collectStrings(key: "text", in: data, limit: 80)
            + ExpediaJSON.collectStrings(key: "primary", in: data, limit: 40)
            + ExpediaJSON.collectStrings(key: "heading", in: data, limit: 40)
        var itemTexts: [String] = []
        ExpediaJSON.walkDepthFirst(data) { node in
            guard let d = node as? [String: Any], let items = d["items"] as? [Any] else { return }
            for item in items {
                if let s = ExpediaJSON.string(item) { itemTexts.append(s) }
            }
        }
        return parseFreeCancellationDeadlines(from: texts + itemTexts)
    }

    static func cancellationDeadlines(fromServicingData data: [String: Any]) -> [CancellationDeadline] {
        var texts = ExpediaJSON.collectStrings(key: "text", in: data, limit: 40)
            + ExpediaJSON.collectStrings(key: "primary", in: data, limit: 40)
            + ExpediaJSON.collectStrings(key: "subtext", in: data, limit: 20)
        ExpediaJSON.walkDepthFirst(data) { node in
            guard let d = node as? [String: Any], let subs = d["subtitles"] as? [Any] else { return }
            for s in subs {
                if let t = ExpediaJSON.string(s) { texts.append(t) }
            }
        }
        return parseFreeCancellationDeadlines(from: texts)
    }

    static func roomCategory(fromRoomDetails data: [String: Any]) -> String? {
        // First roomInfo heading is the room name in HAR fixtures.
        let match = ExpediaJSON.firstDictionary(in: data) { d in
            ExpediaJSON.string(d["__typename"]) == "TripDetailsUIRoomDetailsInfo"
                && ExpediaJSON.string(d["heading"]).map { !$0.isEmpty } == true
        }
        return match.flatMap { ExpediaJSON.string($0["heading"]) }
    }

    /// Parses DE policy lines like
    /// `… bis zum 6. Dez. 2026, 18:00 Uhr (Ortszeit der Unterkunft), kostenlos stornieren.`
    /// Property-local (“Ortszeit”) lines are skipped until a property TZ is known.
    /// Other wall clocks use `Europe/Berlin` (expedia.de / de_DE).
    static func parseFreeCancellationDeadlines(from texts: [String]) -> [CancellationDeadline] {
        var out: [CancellationDeadline] = []
        let pattern =
            #"bis\s+zum\s+(\d{1,2})\.\s*([A-Za-zäöüÄÖÜ.]+)\s+(\d{4}),\s*(\d{1,2}):(\d{2})\s*Uhr"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        for text in texts {
            let lower = text.lowercased()
            guard lower.contains("kostenlos") || lower.contains("free cancellation") else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, options: [], range: range) else { continue }
            func group(_ i: Int) -> String? {
                guard let r = Range(match.range(at: i), in: text) else { return nil }
                return String(text[r])
            }
            guard let d = group(1), let m = group(2), let y = group(3),
                  let h = group(4), let min = group(5),
                  let day = Int(d), let month = ExpediaScheduleParser.monthNumber(m),
                  let year = Int(y), let hour = Int(h), let minute = Int(min)
            else { continue }
            // Property-local wall clock without a known property TZ must not invent Europe/Berlin.
            let propertyLocal = lower.contains("ortszeit")
            guard !propertyLocal else { continue }
            guard let berlin = TimeZone(identifier: "Europe/Berlin"),
                  let deadline = ExpediaScheduleParser.makeBerlinDate(
                    year: year, month: month, day: day, hour: hour, minute: minute
                  )
            else { continue }
            out.append(
                CancellationDeadline(
                    deadlineAt: deadline,
                    policyText: text,
                    isFreeCancellation: true,
                    hotelOffsetSeconds: berlin.secondsFromGMT(for: deadline)
                )
            )
        }
        return out
    }

    private static func looksLikeLodgingCancelURL(_ url: String) -> Bool {
        url.contains("/booking-servicing/") && url.lowercased().contains("cancel")
    }

    private static func confirmedStatusRaw(from texts: [String]) -> String? {
        texts.contains(where: { $0.localizedCaseInsensitiveContains("Gebucht") })
            ? "confirmed"
            : nil
    }

    private static func parseConfirmation(from text: String) -> String? {
        let patterns = [
            #"Bestätigungsnr\.\s*:\s*([A-Z0-9-]+)"#,
            #"Bestätigungsnummer\s*:\s*([A-Z0-9-]+)"#,
            #"Confirmation\s*(?:no|number|#)\s*:?\s*([A-Z0-9-]+)"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let r = Range(match.range(at: 1), in: text)
            {
                return String(text[r])
            }
        }
        return nil
    }

    private static func parseOperator(from texts: [String], bookingType: BookingType) -> String? {
        switch bookingType {
        case .carRental:
            let vendors = ["Dollar", "Hertz", "Avis", "Sixt", "Enterprise", "Alamo", "Budget", "Europcar"]
            return texts.first { vendors.contains($0) }
        default:
            return nil
        }
    }

    private static func parseLocation(
        from texts: [String],
        bookingType: BookingType
    ) -> (from: String?, to: String?) {
        if bookingType == .hotel || bookingType == .carRental {
            if let cityLine = texts.first(where: {
                $0.localizedCaseInsensitiveContains("Mietwagen in ")
                    || $0.localizedCaseInsensitiveContains("Hotel in ")
            }) {
                if let range = cityLine.range(of: " in ", options: .caseInsensitive) {
                    let city = String(cityLine[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if !city.isEmpty { return (city, city) }
                }
            }
        }
        return (nil, nil)
    }
}
