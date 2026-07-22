import Foundation
import ReisenDomain

/// Heuristischer Parser für Stornofristen aus Opodo-HTML / Policy-Strings.
/// Primär: GraphQL `cancellationOptions`; Fallback: sichtbarer Text inkl. Opodo-Formate.
public struct OpodoCancellationDeadlineParser: Sendable {
    public init() {}

    public func parseDeadlines(from html: String) -> [CancellationDeadline] {
        var deadlines: [CancellationDeadline] = []

        // 1) Explizite Opodo-Zeile: „Stornierungsrichtlinie Bis 1. August 2026 (Bis 22:00)“
        deadlines.append(contentsOf: parseStornierungsrichtlinieLines(in: html))

        // 2) Keyword-Fenster (alle Treffer, nicht nur der erste „bis“)
        let lower = html.lowercased()
        let keywords: [String] = [
            "stornierungsrichtlinie",
            "storno",
            "stornieren",
            "stornierbar",
            "kostenlos",
            "free cancellation",
            "refund",
            "cancel",
            "cancelation",
            "until",
            "bis",
        ]

        for keyword in keywords {
            var searchStart = lower.startIndex
            while let range = lower.range(of: keyword, options: [], range: searchStart..<lower.endIndex) {
                let windowRadius = 350
                let start = lower.index(range.lowerBound, offsetBy: -windowRadius, limitedBy: lower.startIndex) ?? lower.startIndex
                let end = lower.index(range.upperBound, offsetBy: windowRadius, limitedBy: lower.endIndex) ?? lower.endIndex
                let snippet = String(html[start..<end])

                if let date = firstDateInSnippet(snippet) {
                    deadlines.append(
                        CancellationDeadline(
                            deadlineAt: date,
                            policyText: snippet.trimmingCharacters(in: .whitespacesAndNewlines),
                            isStrict: true,
                            isFreeCancellation: isFreeCancellation(in: snippet),
                            // Opodo-UI-Zeiten sind Wall-Clock (HAR oft `-00:00`), nicht Geräte-TZ.
                            hotelOffsetSeconds: 0,
                            cancellationFeeAmount: extractFeeAmount(from: snippet)
                        )
                    )
                }
                searchStart = range.upperBound
            }
        }

        var byKey: [String: CancellationDeadline] = [:]
        for deadline in deadlines {
            let key = "\(Int(deadline.deadlineAt.timeIntervalSince1970))"
            if let existing = byKey[key] {
                // Bei gleichem Zeitpunkt: kostenfrei / Stornierungsrichtlinie bevorzugen.
                if deadline.isFreeCancellation && !existing.isFreeCancellation {
                    byKey[key] = deadline
                } else if deadline.isFreeCancellation == existing.isFreeCancellation,
                          (deadline.policyText?.contains("Stornierungsrichtlinie") == true) {
                    byKey[key] = deadline
                }
            } else {
                byKey[key] = deadline
            }
        }
        return byKey.values.sorted { $0.deadlineAt < $1.deadlineAt }
    }
}

private extension OpodoCancellationDeadlineParser {
    // SSOT: Mapping Monatstoken (mit/ohne Punkt) → Monat (1-12)
    private static let monthByToken: [String: Int] = [
        "jan": 1, "januar": 1,
        "feb": 2, "februar": 2,
        "mär": 3, "maerz": 3, "märz": 3, "marz": 3,
        "apr": 4, "april": 4,
        "mai": 5,
        "jun": 6, "juni": 6,
        "jul": 7, "juli": 7,
        "aug": 8, "august": 8,
        "sep": 9, "sept": 9, "september": 9,
        "okt": 10, "oktober": 10,
        "nov": 11, "november": 11,
        "dez": 12, "dezember": 12
    ]

    func parseStornierungsrichtlinieLines(in text: String) -> [CancellationDeadline] {
        // Label optional/mit Whitespace: „Stornierungsrichtlinie Bis 1. August 2026 (Bis 22:00)“
        // Punkt nach Tag optional (UI/i18n: „1. August“ oder „1 August“).
        let patterns = [
            // Monatsabkürzungen können einen Punkt enthalten: „Aug.“ statt „August“.
            // Zusätzlich: zwischen Monat und Jahr kann Opodo auch ohne Whitespace rendern (robuster).
            #"(?i)Stornierungsrichtlinie\s+Bis\s+(\d{1,2}\.?\s*\p{L}+\.?\s*\d{4})(?:\s*\(\s*Bis\s+(\d{1,2}:\d{2})\s*\))?"#,
            #"(?i)(?:^|[\n\r])\s*Bis\s+(\d{1,2}\.?\s*\p{L}+\.?\s*\d{4})(?:\s*\(\s*Bis\s+(\d{1,2}:\d{2})\s*\))?"#,
        ]

        var result: [CancellationDeadline] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let ns = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
            for match in matches {
                guard match.numberOfRanges >= 2,
                      let dateRange = Range(match.range(at: 1), in: text) else { continue }
                let datePart = String(text[dateRange])
                var timePart: String?
                if match.numberOfRanges >= 3, match.range(at: 2).location != NSNotFound,
                   let timeRange = Range(match.range(at: 2), in: text) {
                    timePart = String(text[timeRange])
                }
                guard let deadlineAt = parseGermanLongDate(datePart, time: timePart) else { continue }
                let policyRange = Range(match.range, in: text)
                let policyText = policyRange.map { String(text[$0]).trimmingCharacters(in: .whitespacesAndNewlines) }
                let labeled = (policyText ?? "").localizedCaseInsensitiveContains("Stornierungsrichtlinie")
                result.append(
                    CancellationDeadline(
                        deadlineAt: deadlineAt,
                        policyText: labeled ? policyText : "Stornierungsrichtlinie \(policyText ?? datePart)",
                        isStrict: true,
                        isFreeCancellation: true,
                        hotelOffsetSeconds: 0,
                        cancellationFeeAmount: nil
                    )
                )
            }
        }
        return result
    }

    func isFreeCancellation(in snippet: String) -> Bool {
        let lower = snippet.lowercased()
        return lower.contains("kostenlos")
            || lower.contains("free cancellation")
            || lower.contains("free cancel")
            || lower.contains("vollständig erstatt")
            || lower.contains("vollständige rückerstattung")
            || lower.contains("volle rückerstattung")
            || lower.contains("100 %")
            || lower.contains("100%")
    }

    func firstDateInSnippet(_ snippet: String) -> Date? {
        if let iso = parseISODateFromSnippet(snippet) { return iso }
        if let bis = parseOpodoBisDateFromSnippet(snippet) { return bis }
        if let deDateTime = parseDeDateTimeFromSnippet(snippet) { return deDateTime }
        if let deDate = parseDeDateFromSnippet(snippet) { return deDate }
        return nil
    }

    func parseGermanLongDate(_ datePart: String, time: String?) -> Date? {
        let normalized = normalizeGermanLongDatePart(datePart)
        let tokenized = tokenizeGermanLongDate(normalized)

        if tokenized.count >= 3 {
            if let parsed = parseGermanLongDateDayMonthYear(parts: tokenized, time: time) {
                return parsed
            }
            if let parsed = parseGermanLongDateMonthDayYear(parts: tokenized, time: time) {
                return parsed
            }
        }

        return parseGermanLongDateWithDateFormatter(normalized: normalized, time: time)
    }

    private func parseISODateFromSnippet(_ snippet: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()

        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let match = firstMatch(
            pattern: #"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2}))"#,
            in: snippet
        ) {
            if let date = isoFormatter.date(from: match) { return date }
        }

        isoFormatter.formatOptions = [.withInternetDateTime]
        if let match = firstMatch(
            pattern: #"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:?\d{2}))"#,
            in: snippet
        ) {
            if let date = isoFormatter.date(from: match) { return date }
        }

        return nil
    }

    private func parseOpodoBisDateFromSnippet(_ snippet: String) -> Date? {
        let match = firstMatch(
            pattern: #"(?i)(\d{1,2}\.?\s*\p{L}+\.?\s*\d{4})(?:\s*\(\s*Bis\s+(\d{1,2}:\d{2})\s*\))?"#,
            in: snippet
        ) ?? nil

        guard let _ = match else { return nil }

        guard let datePart = firstMatch(
            pattern: #"(?i)(\d{1,2}\.?\s*\p{L}+\.?\s*\d{4})"#,
            in: snippet
        ) else { return nil }

        let timePart = firstMatch(
            pattern: #"(?i)\(\s*Bis\s+(\d{1,2}:\d{2})\s*\)"#,
            in: snippet
        )

        return parseGermanLongDate(datePart, time: timePart)
    }

    private func parseDeDateTimeFromSnippet(_ snippet: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "dd.MM.yyyy HH:mm"

        guard let match = firstMatch(
            pattern: #"(\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2})(?:\s*uhr)?"#,
            in: snippet
        ) else { return nil }

        return formatter.date(from: match)
    }

    private func parseDeDateFromSnippet(_ snippet: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "dd.MM.yyyy"

        guard let match = firstMatch(pattern: #"(\d{2}\.\d{2}\.\d{4})"#, in: snippet) else { return nil }
        return formatter.date(from: match)
    }

    private func normalizeGermanLongDatePart(_ datePart: String) -> String {
        datePart
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenizeGermanLongDate(_ normalized: String) -> [Substring] {
        var s = normalized

        // Tag/Monat trennen: "1.Aug." → "1. Aug."
        if let r = try? NSRegularExpression(
            pattern: #"(?i)(\d{1,2}\.?)\s*([A-Za-zÄÖÜäöü]{2,}\.?)"#
        ) {
            s = r.stringByReplacingMatches(
                in: s,
                options: [],
                range: NSRange(location: 0, length: (s as NSString).length),
                withTemplate: "$1 $2"
            )
        }

        // Monat/Jahr trennen: "Aug.2026" → "Aug. 2026"
        if let r = try? NSRegularExpression(
            pattern: #"(?i)([A-Za-zÄÖÜäöü]{2,}\.?)\s*(\d{4})"#
        ) {
            s = r.stringByReplacingMatches(
                in: s,
                options: [],
                range: NSRange(location: 0, length: (s as NSString).length),
                withTemplate: "$1 $2"
            )
        }

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
    }

    private func parseGermanLongDateDayMonthYear(
        parts: [Substring],
        time: String?
    ) -> Date? {
        guard parts.count >= 3 else { return nil }
        let dayToken = String(parts[0]).replacingOccurrences(of: ".", with: "")
        let monthToken = String(parts[1]).lowercased().replacingOccurrences(of: ".", with: "")
        let yearToken = String(parts[2]).filter(\.isNumber)

        guard let day = Int(dayToken), let year = Int(yearToken), let month = Self.monthByToken[monthToken] else {
            return nil
        }

        return buildGermanLongDate(day: day, month: month, year: year, time: time)
    }

    private func parseGermanLongDateMonthDayYear(
        parts: [Substring],
        time: String?
    ) -> Date? {
        guard parts.count >= 3 else { return nil }
        let monthToken = String(parts[0]).lowercased().replacingOccurrences(of: ".", with: "")
        let dayToken = String(parts[1]).replacingOccurrences(of: ".", with: "")
        let yearToken = String(parts[2]).filter(\.isNumber)

        guard let day = Int(dayToken), let year = Int(yearToken), let month = Self.monthByToken[monthToken] else {
            return nil
        }

        return buildGermanLongDate(day: day, month: month, year: year, time: time)
    }

    private func buildGermanLongDate(
        day: Int,
        month: Int,
        year: Int,
        time: String?
    ) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents(
            calendar: calendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day
        )

        guard let time, !time.isEmpty else {
            return calendar.date(from: components)
        }

        let timeParts = time
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":")

        if timeParts.count == 2,
           let hour = Int(timeParts[0]),
           let minute = Int(timeParts[1]) {
            components.hour = hour
            components.minute = minute
        }

        return calendar.date(from: components)
    }

    private func parseGermanLongDateWithDateFormatter(
        normalized: String,
        time: String?
    ) -> Date? {
        let normalizedWithoutMonthDot = removeTrailingMonthDot(normalized)
        let withDot = ensureLeadingDayDot(normalizedWithoutMonthDot)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        if let time, !time.isEmpty {
            formatter.dateFormat = "d. MMMM yyyy HH:mm"
            if let date = formatter.date(from: "\(withDot) \(time)") { return date }

            formatter.dateFormat = "d. MMM yyyy HH:mm"
            if let date = formatter.date(from: "\(withDot) \(time)") { return date }
        }

        formatter.dateFormat = "d. MMMM yyyy"
        if let date = formatter.date(from: withDot) { return date }

        formatter.dateFormat = "d. MMM yyyy"
        return formatter.date(from: withDot)
    }

    private func removeTrailingMonthDot(_ normalized: String) -> String {
        let pattern = #"(?i)(\b[A-Za-zÄÖÜäöü]{3,})\."#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return normalized }
        let ns = normalized as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        return regex.stringByReplacingMatches(in: normalized, options: [], range: fullRange, withTemplate: "$1")
    }

    private func ensureLeadingDayDot(_ normalizedWithoutMonthDot: String) -> String {
        let pattern = #"^(\d{1,2})(\s+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return normalizedWithoutMonthDot }
        let ns = normalizedWithoutMonthDot as NSString
        let fullRange = NSRange(location: 0, length: ns.length)

        if regex.firstMatch(in: normalizedWithoutMonthDot, options: [], range: fullRange) != nil,
           !normalizedWithoutMonthDot.contains(".") {
            return regex.stringByReplacingMatches(
                in: normalizedWithoutMonthDot,
                options: [],
                range: fullRange,
                withTemplate: "$1.$2"
            )
        }

        return normalizedWithoutMonthDot
    }

    private func parseGermanDayMonthYear(_ input: String) -> (Int, Int, Int)? {
        // Erwartet grob: „<day>[.] <monthToken>[.] <year>“
        // Beispiel: „1 August 2026“, „1. Aug. 2026“, „01 März 2026“
        // Nutzt Unicode Buchstabenklasse, damit auch ungewöhnliche Token (z. B. „Mär“)
        // ohne Spezial-Casing sicher gematcht werden.
        let pattern = #"(?i)^\s*(\d{1,2})\.\?\s*([\p{L}]{2,})\s*\.?\s*(\d{4})\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = input as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: input, options: [], range: fullRange),
              match.numberOfRanges >= 4,
              let dayRange = Range(match.range(at: 1), in: input),
              let monthRange = Range(match.range(at: 2), in: input),
              let yearRange = Range(match.range(at: 3), in: input),
              let day = Int(input[dayRange]),
              let year = Int(input[yearRange]) else { return nil }

        let monthToken = String(input[monthRange]).lowercased().replacingOccurrences(of: ".", with: "")

        if let month = Self.monthByToken[monthToken] {
            return (day, month, year)
        }
        return nil
    }

    func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: text, options: [], range: fullRange) else { return nil }
        let rangeIndex = match.numberOfRanges > 1 ? 1 : 0
        let range = match.range(at: rangeIndex)
        guard range.location != NSNotFound else { return nil }
        return ns.substring(with: range)
    }

    func extractFeeAmount(from snippet: String) -> Double? {
        let patterns: [String] = [
            #"(\€|EUR)\s*([0-9]+(?:[.,][0-9]{1,2})?)"#,
            #"fee\s*[:=]?\s*([0-9]+(?:[.,][0-9]{1,2})?)"#,
            #"gebühr\s*[:=]?\s*(?:\€|EUR)?\s*([0-9]+(?:[.,][0-9]{1,2})?)"#,
        ]
        for pattern in patterns {
            if let match = firstMatch(pattern: pattern, in: snippet),
               let number = firstMatch(pattern: #"[0-9]+(?:[.,][0-9]{1,2})?"#, in: match) {
                let normalized = number.replacingOccurrences(of: ",", with: ".")
                return Double(normalized)
            }
        }
        return nil
    }
}
