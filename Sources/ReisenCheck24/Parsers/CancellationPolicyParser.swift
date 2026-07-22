import Foundation
import ReisenDomain

public struct CancellationPolicyParsed {
    public let deadlines: [ParsedCancellationDeadline]
    public let title: String?
    public let stayStartDate: Date?
    public let stayEndDate: Date?

    public init(
        deadlines: [ParsedCancellationDeadline],
        title: String?,
        stayStartDate: Date?,
        stayEndDate: Date?
    ) {
        self.deadlines = deadlines
        self.title = title
        self.stayStartDate = stayStartDate
        self.stayEndDate = stayEndDate
    }
}

/// Extrahiert Stornofristen aus der Policy-Seite, die im HTML als eingebettete JSON-Strukturen vorliegt.
public struct CancellationPolicyParser {
    public init() {}

    public func parseCancellationPolicy(from html: String) -> CancellationPolicyParsed {
        let deadlines = parseDeadlines(from: html)
        let title = extractTitle(from: html)
        let stay = parseStayDates(from: html)
        return CancellationPolicyParsed(
            deadlines: deadlines,
            title: title,
            stayStartDate: stay?.startDate,
            stayEndDate: stay?.endDate
        )
    }

    private func extractTitle(from html: String) -> String? {
        // Beispiel: <title>Taman Sari Bali Resort and Spa</title>
        let pattern = #"<title>([^<]{3,200})</title>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = html as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: html, range: fullRange) else { return nil }
        let range = match.range(at: 1)
        guard range.location != NSNotFound else { return nil }
        return ns.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseDeadlines(from html: String) -> [ParsedCancellationDeadline] {
        // Policy-JSON enthält z. B.:
        // cancelationLabelFee":"Kostenlos stornierbar"
        // cancelationLabelTime":"bis zum 13.07.2026 21:59 Uhr (Hotel-Ortszeit)"
        // cancelableUntilHotel":"2026-08-12T21:59:59+0800"
        // cancelableUntilUtc":"2026-08-12T13:59:59+0000"
        // Check24 liefert die eingebettete Policy-JSON je nach Kontext unterschiedlich escapt.
        // Wir normalisieren die gängigen Escape-Formen, damit die Regex zuverlässig matcht.
        let norm = html
            .replacingOccurrences(of: "\\u00a0", with: " ")
            .replacingOccurrences(of: "\\u20ac", with: "€")
            // In HTML kann JSON typischerweise als String mit `\"`-Escapes vorkommen.
            // Danach passen Regex-Muster ohne Backslash-Quoting besser.
            .replacingOccurrences(of: "\\\"", with: "\"")

        // Suche nach `cancelationLabelFee` + `cancelationLabelTime`-Paaren und ordne anschließend
        // das nächstliegende `cancelableUntilHotel`/`cancelableUntilUtc` zu.
        let pattern = #"cancelationLabelFee"\s*:\s*"([^"]+?)"\s*.*?cancelationLabelTime"\s*:\s*"([^"]+?)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }

        let ns = norm as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: norm, range: fullRange)
        guard !matches.isEmpty else { return [] }

        var deadlines: [ParsedCancellationDeadline] = []
        let dtFormatterHotel = CancellationPolicyDateFormats.hotelDateTimeFormatter
        let dtFormatterUtc = CancellationPolicyDateFormats.utcDateTimeFormatter
        let clauseFormatter = CancellationPolicyClauseFormatter()

        for m in matches {
            if m.numberOfRanges < 3 { continue }
            let feeLabel = ns.substring(with: m.range(at: 1))
            let labelTime = ns.substring(with: m.range(at: 2))

            // Umgebung um den Match herum durchsuchen, um die passenden cancelableUntil-Felder zu finden.
            let matchPos = m.range.location
            let windowStart = max(0, matchPos - 200)
            let windowEnd = min(ns.length, matchPos + 6000)
            let window = ns.substring(with: NSRange(location: windowStart, length: windowEnd - windowStart))

            let hotelUntil = extractValue(from: window, key: "cancelableUntilHotel")
            let utcUntil = extractValue(from: window, key: "cancelableUntilUtc")

            let hotelOffsetSeconds = extractHotelOffsetSeconds(from: window)
            let cancellationFeeAmount =
                extractCancellationFeeAmount(from: window)
                ?? extractCancellationFeeAmount(fromFeeLabel: feeLabel)

            let deadlineAt: Date? =
                parseDeadlineFromLabelTime(labelTime, window: window)?.deadlineAt ??
                (hotelUntil.flatMap { dtFormatterHotel.date(from: $0) }) ??
                (utcUntil.flatMap { dtFormatterUtc.date(from: $0) })

            let parsedHotelOffsetSeconds =
                parseDeadlineFromLabelTime(labelTime, window: window)?.offsetSeconds ??
                hotelOffsetSeconds

            guard let deadlineAt else { continue }

            let isStrict = clauseFormatter.isStrictFromLabelTime(labelTime)
            let isFreeCancellation = clauseFormatter.isFreeCancellationFee(feeLabel)
            let policyText = clauseFormatter.policyText(feeLabel: feeLabel, labelTime: labelTime)
            deadlines.append(
                ParsedCancellationDeadline(
                    deadlineAt: deadlineAt,
                    policyText: policyText,
                    isStrict: isStrict,
                    isFreeCancellation: isFreeCancellation,
                    hotelOffsetSeconds: parsedHotelOffsetSeconds,
                    cancellationFeeAmount: cancellationFeeAmount
                )
            )
        }

        // Deduping:
        // Check24 kann mehrere Policy-Stufen mit identischem `deadlineAt` liefern
        // (z.B. "from/after/bis" Varianten). Daher dedupen wir nicht nur nach Zeitpunkt,
        // sondern nach einem Composite-Key inkl. Fee-Information.
        var byKey: [String: ParsedCancellationDeadline] = [:]
        for d in deadlines {
            let feeKey: String = {
                if let amount = d.cancellationFeeAmount {
                    // stabiler Schlüssel in Cent statt Double
                    return "\(Int((amount * 100.0).rounded()))"
                }
                // falls keine Fee bekannt: policyText als Schlüsselbasis nutzen
                return d.policyText?.lowercased() ?? ""
            }()

            let key = "\(Int(d.deadlineAt.timeIntervalSince1970))|\(d.isFreeCancellation)|\(d.isStrict)|\(feeKey)"
            byKey[key] = d
        }

        return byKey.values.sorted { $0.deadlineAt < $1.deadlineAt }
    }

    private func extractValue(from window: String, key: String) -> String? {
        // Beispiel: cancelableUntilHotel":"2026-08-12T21:59:59+0800"
        // oder (fallback) bereits unescaped: cancelableUntilHotel":"...
        let pattern = "\(key)\"\\s*:\\s*\"([^\"]+?)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = window as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: window, range: fullRange) else { return nil }
        let range = match.range(at: 1)
        guard range.location != NSNotFound else { return nil }
        return ns.substring(with: range)
    }

    private func parseDeadlineFromLabelTime(
        _ labelTime: String,
        window: String
    ) -> (deadlineAt: Date, offsetSeconds: Int)? {
        // labelTime: "bis zum 13.07.2026 21:59 Uhr (Hotel-Ortszeit)"
        let dtPattern = #"(\d{2}\.\d{2}\.\d{4})\s+(\d{2}:\d{2})"#
        guard let dtRegex = try? NSRegularExpression(pattern: dtPattern, options: [.caseInsensitive]) else { return nil }
        let ns = labelTime as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        guard let match = dtRegex.firstMatch(in: labelTime, range: fullRange) else { return nil }

        let datePart = ns.substring(with: match.range(at: 1))
        let timePart = ns.substring(with: match.range(at: 2))
        let dateTimeString = "\(datePart) \(timePart)"

        guard let offsetSeconds = extractHotelOffsetSeconds(from: window) else { return nil }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: offsetSeconds)
        df.dateFormat = "dd.MM.yyyy HH:mm"
        guard let deadlineAt = df.date(from: dateTimeString) else { return nil }
        return (deadlineAt: deadlineAt, offsetSeconds: offsetSeconds)
    }

    private func extractHotelOffsetSeconds(from window: String) -> Int? {
        // cancelableUntilHotel enthält den Offset: "+0800" / "-0530"
        // In HTML/JSON kommen beide Schreibweisen vor:
        // - escaped:   cancelableUntilHotel\":\"2026-...+0800\"
        // - unescaped: cancelableUntilHotel":"2026-...+0800"
        let pattern = #"cancelableUntilHotel\"?\s*:\s*\"[^\"]+?([+-]\d{4})\""# // group(1) = +0800 / -0530
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = window as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: window, range: fullRange) else { return nil }
        guard match.numberOfRanges >= 2 else { return nil }
        let offset = ns.substring(with: match.range(at: 1)) // +0800
        guard offset.count == 5 else { return nil }
        let signChar = offset.first
        let hoursStr = String(offset.dropFirst(1).prefix(2))
        let minsStr = String(offset.dropFirst(3).prefix(2))
        guard let hours = Int(hoursStr), let mins = Int(minsStr) else { return nil }
        let seconds = hours * 3600 + mins * 60
        return signChar == "-" ? -seconds : seconds
    }

    private func extractCancellationFeeAmount(from window: String) -> Double? {
        // cancelationFee: 0 / 376.6 (oder ähnlich)
        let pattern = #"cancelationFee"\s*:\s*([0-9]+(?:\.[0-9]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = window as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: window, options: [], range: fullRange),
              match.numberOfRanges >= 2 else { return nil }

        let raw = ns.substring(with: match.range(at: 1))
        // Absichern: Dezimaltrenner ggf. auf Punkt normalisieren.
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func extractCancellationFeeAmount(fromFeeLabel feeLabel: String) -> Double? {
        // Fallback aus Fee-Text, z.B. "... für 234,90 €" / "... für 469,80 €"
        let pattern = #"(\d{1,3}(?:\.\d{3})*|\d+)[.,]\d{2}\s*€"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = feeLabel as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: feeLabel, range: fullRange),
              match.numberOfRanges >= 1,
              let matchRange = Range(match.range(at: 0), in: feeLabel) else { return nil }

        let raw = feeLabel[matchRange]
            .replacingOccurrences(of: "€", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Bestimme Decimaltrenner anhand des letzten Auftretens von ',' / '.'
        let hasComma = raw.contains(",")
        let hasDot = raw.contains(".")
        let decimalSeparator: Character? = {
            if hasComma && hasDot {
                let commaIndex = raw.lastIndex(of: ",")!
                let dotIndex = raw.lastIndex(of: ".")!
                return commaIndex > dotIndex ? "," : "."
            }
            if hasComma { return "," }
            if hasDot { return "." }
            return nil
        }()
        guard let decimalSeparator else { return nil }

        let normalized: String = {
            if hasComma && hasDot {
                // tausendertrenner entfernen
                let thousandSeparator = decimalSeparator == "," ? "." : ","
                return raw
                    .replacingOccurrences(of: String(thousandSeparator), with: "")
                    .replacingOccurrences(of: String(decimalSeparator), with: ".")
            }
            return raw.replacingOccurrences(of: String(decimalSeparator), with: ".")
        }()

        return Double(normalized)
    }

    private func parseStayDates(from html: String) -> (startDate: Date, endDate: Date)? {
        // Beispiel im HTML (aus deinem HAR):
        // "stay":{"startsOn":"2026-08-13","endsOn":"2026-08-16",...}
        let pattern = #"\"stay\"\\s*:\\s*\\{\\s*\"startsOn\"\\s*:\\s*\"(\\d{4}-\\d{2}-\\d{2})\"\\s*,\\s*\"endsOn\"\\s*:\\s*\"(\\d{4}-\\d{2}-\\d{2})\""# 
        // Hinweis: Regex mit Escapes, deshalb raw string.
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = html as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: html, range: fullRange) else { return nil }
        guard match.numberOfRanges >= 3 else { return nil }
        let startRaw = ns.substring(with: match.range(at: 1))
        let endRaw = ns.substring(with: match.range(at: 2))

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"
        guard let startDate = df.date(from: startRaw), let endDate = df.date(from: endRaw) else { return nil }
        return (startDate: startDate, endDate: endDate)
    }

    private func decodeDeadlineAt(
        hotelUntil: String?,
        utcUntil: String?,
        labelTime: String,
        dtFormatterHotel: DateFormatter,
        dtFormatterUtc: DateFormatter
    ) -> Date? {
        if let hotelUntil, let d = dtFormatterHotel.date(from: hotelUntil) {
            return d
        }
        if let utcUntil, let d = dtFormatterUtc.date(from: utcUntil) {
            return d
        }

        // Fallback ohne UTC/Hotel-Feld ist riskant (Hotel-Ortszeit). Daher nur wenn labelTime eindeutig ist:
        // "bis zum 13.07.2026 21:59 Uhr ..." -> Date nur als "local" ohne garantierte TZ ist fehleranfällig.
        // Um keine falsche Semantik einzubauen: hier skippen statt Dummy.
        return nil
    }
}

private enum CancellationPolicyDateFormats {
    // cancelableUntilHotel: "2026-08-12T21:59:59+0800"
    static var hotelDateTimeFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f
    }

    // cancelableUntilUtc: "2026-08-12T13:59:59+0000"
    static var utcDateTimeFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f
    }
}

private struct CancellationPolicyClauseFormatter {
    public func isStrictFromLabelTime(_ labelTime: String) -> Bool {
        labelTime.lowercased().contains("bis zum")
    }

    public func isFreeCancellationFee(_ feeLabel: String) -> Bool {
        // Bestimmung „kostenlos stornierbar“ aus dem Fee-Label.
        // Beispiel: „Kostenlos stornierbar“
        let lower = feeLabel.lowercased()
        return lower.contains("kostenlos") && lower.contains("stornier")
    }

    public func policyText(feeLabel: String, labelTime: String) -> String? {
        let fee = feeLabel.replacingOccurrences(of: "\\u00fcr", with: "ü").replacingOccurrences(of: "\\u00fc", with: "ü")
        let fixedFee = fixTypoForStornierbarFee(fee)
        return "\(fixedFee) – \(labelTime)"
    }

    private func fixTypoForStornierbarFee(_ fee: String) -> String {
        // observed: "stornierbar fü" statt "stornierbar für"
        // Normalisiere NBSP -> normal space, damit eine einfache String-Ersetzung robust funktioniert.
        let normalized = fee.replacingOccurrences(of: "\u{00A0}", with: " ")

        // Haupt-Fix:
        // Check24 zeigt teils "stornierbar fürr" (doppeltes r) statt "stornierbar für".
        // Daher: ersetze alles im Muster "stornierbar fü+r+" auf "stornierbar für".
        //
        // Beispiele:
        // - stornierbar fürr  -> stornierbar für
        // - stornierbar fürrr -> stornierbar für
        let pattern = "stornierbar\\\\s+f\\u{00FC}r+"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
            return regex.stringByReplacingMatches(in: normalized, options: [], range: range, withTemplate: "stornierbar für")
        }

        // Fallback: einfache Ersetzung.
        return normalized
            .replacingOccurrences(of: "stornierbar fürr", with: "stornierbar für")
            .replacingOccurrences(of: "stornierbar fü", with: "stornierbar für")
    }
}

// (kein Dedup-Helper notwendig)

