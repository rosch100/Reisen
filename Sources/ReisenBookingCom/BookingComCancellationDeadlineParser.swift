import Foundation
import ReisenDomain

/// Parser für Stornofristen aus Booking.com-HTML (Confirmation Fee-Schedule + Heuristik).
///
/// HAR Confirmation (`e2e-cancellation-breakdown`): Fee-Schedule ist die SSOT
/// („bis … / ab …“, Beträge, „gemäß der Zeitzone der Unterkunft“).
public struct BookingComCancellationDeadlineParser: Sendable {
    public init() {}

    /// - Parameter hotelOffsetSeconds: Pflicht für korrekte Ortszeiten; ohne Offset keine Fristen
    ///   (kein stilles UTC, HAR: Zeitzone der Unterkunft).
    public func parseDeadlines(from html: String, hotelOffsetSeconds: Int? = nil) -> [CancellationDeadline] {
        guard let offset = hotelOffsetSeconds else { return [] }

        let feeSchedule = parseFeeSchedule(from: html, hotelOffsetSeconds: offset)
        if !feeSchedule.isEmpty {
            return dedupe(feeSchedule)
        }
        // Markup vorhanden, aber Zeilen nicht lesbar → kein Keyword-Müll (z. B. falsches „vor dem“).
        if hasFeeScheduleMarkup(html) {
            return []
        }
        return dedupe(parseKeywordWindows(from: html, hotelOffsetSeconds: offset))
    }
}

private extension BookingComCancellationDeadlineParser {
    func hasFeeScheduleMarkup(_ html: String) -> Bool {
        let lower = html.lowercased()
        return lower.contains("e2e-cancellation-breakdown")
            || lower.contains("e2e-conf-cancellation-cost")
            || lower.contains("stornierungsgebühren")
    }

    /// HAR (`confirmation.html`): `e2e-cancellation-breakdown` mit
    /// „bis 10. August 2026 23:59: € 0“ / „ab 11. August 2026 00:00: € 121,64“.
    func parseFeeSchedule(from html: String, hotelOffsetSeconds: Int) -> [CancellationDeadline] {
        let source = feeScheduleSource(from: html)
        var deadlines = parseLongGermanFeeRows(from: source, hotelOffsetSeconds: hotelOffsetSeconds)
        if deadlines.isEmpty {
            deadlines = parseNumericGermanFeeRows(from: source, hotelOffsetSeconds: hotelOffsetSeconds)
        }
        return deadlines
    }

    func feeScheduleSource(from html: String) -> String {
        let normalized = BookingComParsing.normalizeEuroEntities(html)
        if let section = BookingComParsing.capture(
            #"(?s)e2e-conf-cancellation-cost.*?gemäß der Zeitzone der Unterkunft"#,
            in: normalized
        ) {
            return section
        }
        if let section = BookingComParsing.capture(
            #"(?s)e2e-conf-cancellation-cost.*?</table>"#,
            in: normalized
        ) {
            return section
        }
        if let breakdown = BookingComParsing.capture(
            #"(?s)e2e-cancellation-breakdown.*?</ul>"#,
            in: normalized
        ) {
            return breakdown
        }
        return normalized
    }

    func parseLongGermanFeeRows(from html: String, hotelOffsetSeconds: Int) -> [CancellationDeadline] {
        guard let regex = try? NSRegularExpression(
            // DE: bis/ab 10. August … — EN: until/from 10 August …
            pattern: #"(bis|ab|until|from)\s+(\d{1,2}\.?\s*[A-Za-zÄÖÜäöüß]+?\s+\d{4})\s+(\d{2}:\d{2}).{0,400}?(?:€|EUR)\s*([0-9]+(?:[.,][0-9]{1,2})?)"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }

        let ns = html as NSString
        let full = NSRange(location: 0, length: ns.length)
        var deadlines: [CancellationDeadline] = []

        regex.enumerateMatches(in: html, options: [], range: full) { match, _, _ in
            guard let match, match.numberOfRanges >= 5 else { return }
            let prefix = ns.substring(with: match.range(at: 1)).lowercased()
            let datePart = ns.substring(with: match.range(at: 2))
            let timePart = ns.substring(with: match.range(at: 3))
            let amountRaw = ns.substring(with: match.range(at: 4))
            guard let amount = Double(amountRaw.replacingOccurrences(of: ",", with: ".")),
                  let deadlineAt = BookingComParsing.parseGermanLongDateTime(
                    in: "\(datePart) \(timePart)",
                    offsetSeconds: hotelOffsetSeconds
                  ) else {
                return
            }
            deadlines.append(
                CancellationDeadline(
                    deadlineAt: deadlineAt,
                    policyText: feePolicyText(prefix: prefix, datePart: datePart, timePart: timePart, amount: amount),
                    isStrict: true,
                    isFreeCancellation: amount == 0,
                    hotelOffsetSeconds: hotelOffsetSeconds,
                    cancellationFeeAmount: amount
                )
            )
        }
        return deadlines
    }

    func parseNumericGermanFeeRows(from html: String, hotelOffsetSeconds: Int) -> [CancellationDeadline] {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?:bis|ab)?\s*(\d{2}\.\d{2}\.\d{4})(?:\s+(\d{2}:\d{2}))?.{0,120}?(?:€|EUR)\s*([0-9]+(?:[.,][0-9]{1,2})?)"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }

        let ns = html as NSString
        let full = NSRange(location: 0, length: ns.length)
        var deadlines: [CancellationDeadline] = []

        regex.enumerateMatches(in: html, options: [], range: full) { match, _, _ in
            guard let match, match.numberOfRanges >= 4 else { return }
            let datePart = ns.substring(with: match.range(at: 1))
            let timePart = match.range(at: 2).location != NSNotFound
                ? ns.substring(with: match.range(at: 2))
                : "23:59"
            let amountRaw = ns.substring(with: match.range(at: 3))
            guard let amount = Double(amountRaw.replacingOccurrences(of: ",", with: ".")),
                  let deadlineAt = BookingComParsing.parseGermanDateTime(
                    "\(datePart) \(timePart)",
                    offsetSeconds: hotelOffsetSeconds
                  ) else {
                return
            }
            let matched = ns.substring(with: match.range).lowercased()
            let prefix = matched.contains("ab ") || matched.hasPrefix("ab") ? "ab" : "bis"
            deadlines.append(
                CancellationDeadline(
                    deadlineAt: deadlineAt,
                    policyText: feePolicyText(prefix: prefix, datePart: datePart, timePart: timePart, amount: amount),
                    isStrict: true,
                    isFreeCancellation: amount == 0,
                    hotelOffsetSeconds: hotelOffsetSeconds,
                    cancellationFeeAmount: amount
                )
            )
        }
        return deadlines
    }

    func feePolicyText(prefix: String, datePart: String, timePart: String, amount: Double) -> String {
        let amountText: String
        if abs(amount.rounded() - amount) < 0.000_1 {
            amountText = String(Int(amount.rounded()))
        } else {
            amountText = String(format: "%.2f", amount).replacingOccurrences(of: ".", with: ",")
        }
        return "\(prefix) \(datePart) \(timePart): € \(amountText)"
    }

    func parseKeywordWindows(from html: String, hotelOffsetSeconds: Int) -> [CancellationDeadline] {
        let keywords = [
            "kostenlos stornieren", "kostenlose stornierung",
            "free cancellation", "free_cancellation",
            "haveTimeLeftForFreeCancellation",
            "stornogebühr", "cancellation fee",
        ]
        let lower = html.lowercased()
        var deadlines: [CancellationDeadline] = []

        for keyword in keywords {
            var searchStart = lower.startIndex
            while let range = lower.range(of: keyword, options: [], range: searchStart..<lower.endIndex) {
                let windowRadius = 160
                let start = lower.index(range.lowerBound, offsetBy: -windowRadius, limitedBy: lower.startIndex) ?? lower.startIndex
                let end = lower.index(range.upperBound, offsetBy: windowRadius, limitedBy: lower.endIndex) ?? lower.endIndex
                let snippet = String(html[start..<end])
                let normalizedSnippet = BookingComParsing.normalizeEuroEntities(snippet)
                let snippetLower = normalizedSnippet.lowercased()

                guard let date = deadlineDate(from: normalizedSnippet, hotelOffsetSeconds: hotelOffsetSeconds) else {
                    searchStart = range.upperBound
                    continue
                }

                let amount = extractFeeAmount(from: normalizedSnippet)
                let isFree = amount == 0
                    || snippetLower.contains("free cancellation")
                    || snippetLower.contains("free_cancellation")
                    || snippetLower.contains("kostenlos")
                    || (amount == nil && (snippetLower.contains("kostenlos") || snippetLower.contains("free")))

                deadlines.append(
                    CancellationDeadline(
                        deadlineAt: date,
                        policyText: cleanedPolicyText(normalizedSnippet),
                        isStrict: true,
                        isFreeCancellation: isFree,
                        hotelOffsetSeconds: hotelOffsetSeconds,
                        cancellationFeeAmount: amount ?? (isFree ? 0 : nil)
                    )
                )
                searchStart = range.upperBound
            }
        }
        return deadlines
    }

    func deadlineDate(from snippet: String, hotelOffsetSeconds: Int) -> Date? {
        let lower = snippet.lowercased()
        if lower.contains("vor dem") || lower.contains("before") {
            return BookingComParsing.parseExclusiveGermanPolicyDate(
                in: snippet,
                offsetSeconds: hotelOffsetSeconds
            )
        }
        return firstDateInSnippet(snippet, hotelOffsetSeconds: hotelOffsetSeconds)
    }

    func firstDateInSnippet(_ snippet: String, hotelOffsetSeconds: Int) -> Date? {
        if let match = BookingComParsing.capture(
            #"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2}))"#,
            in: snippet
        ), let date = BookingComParsing.parseISODateTime(match) {
            return date
        }
        if let match = BookingComParsing.capture(
            #"(\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2})"#,
            in: snippet
        ), let date = BookingComParsing.parseGermanDateTime(match, offsetSeconds: hotelOffsetSeconds) {
            return date
        }
        if let match = BookingComParsing.capture(
            #"(\d{1,2}\.\s*[A-Za-zÄÖÜäöüß]+\s+\d{4}\s+\d{2}:\d{2})"#,
            in: snippet
        ), let date = BookingComParsing.parseGermanLongDateTime(in: match, offsetSeconds: hotelOffsetSeconds) {
            return date
        }
        if let match = BookingComParsing.capture(#"(\d{2}\.\d{2}\.\d{4})"#, in: snippet),
           let date = BookingComParsing.parseGermanDateEndOfDay(match, offsetSeconds: hotelOffsetSeconds) {
            return date
        }
        return BookingComParsing.parseGermanLongDate(
            in: snippet,
            endOfDay: true,
            offsetSeconds: hotelOffsetSeconds
        )
    }

    func extractFeeAmount(from snippet: String) -> Double? {
        let patterns = [
            #"gebühr\s*[:=]?\s*(?:€|EUR)?\s*([0-9]+(?:[.,][0-9]{1,2})?)"#,
            #"(?:€|EUR)\s*([0-9]+(?:[.,][0-9]{1,2})?)"#,
        ]
        for pattern in patterns {
            if let number = BookingComParsing.capture(pattern, in: snippet) {
                return Double(number.replacingOccurrences(of: ",", with: "."))
            }
        }
        return nil
    }

    func cleanedPolicyText(_ raw: String) -> String {
        var text = BookingComParsing.normalizeEuroEntities(raw)
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func dedupe(_ deadlines: [CancellationDeadline]) -> [CancellationDeadline] {
        var byKey: [String: CancellationDeadline] = [:]
        for d in deadlines {
            let feeKey = d.cancellationFeeAmount.map { String(Int(($0 * 100).rounded())) } ?? ""
            let key = "\(Int(d.deadlineAt.timeIntervalSince1970))|\(d.isFreeCancellation)|\(feeKey)"
            byKey[key] = d
        }
        return byKey.values.sorted { $0.deadlineAt < $1.deadlineAt }
    }
}
