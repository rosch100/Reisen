import Foundation
import ReisenDomain

public struct ParsedBookingDetails {
    public let rawDetailsFingerprint: String

    // Common (hotel + flights)
    public let totalPriceAmount: Double?
    public let totalPriceCurrency: String?

    // Hotel
    public let roomCategory: String?
    public let boardTypeRaw: String?
    public let includedBreakfast: Bool?
    public let guestCount: Int?
    public let roomCount: Int?

    // Flights/Fähren (optional)
    public let airline: String?
    public let passengerCount: Int?
    public let baggageInfoRaw: String?

    public init(
        rawDetailsFingerprint: String,
        totalPriceAmount: Double? = nil,
        totalPriceCurrency: String? = nil,
        roomCategory: String? = nil,
        boardTypeRaw: String? = nil,
        includedBreakfast: Bool? = nil,
        guestCount: Int? = nil,
        roomCount: Int? = nil,
        airline: String? = nil,
        passengerCount: Int? = nil,
        baggageInfoRaw: String? = nil
    ) {
        self.rawDetailsFingerprint = rawDetailsFingerprint
        self.totalPriceAmount = totalPriceAmount
        self.totalPriceCurrency = totalPriceCurrency
        self.roomCategory = roomCategory
        self.boardTypeRaw = boardTypeRaw
        self.includedBreakfast = includedBreakfast
        self.guestCount = guestCount
        self.roomCount = roomCount
        self.airline = airline
        self.passengerCount = passengerCount
        self.baggageInfoRaw = baggageInfoRaw
    }
}

public struct BookingDetailsParser {
    public init() {}

    public func parse(from html: String, bookingType: BookingType) -> ParsedBookingDetails {
        // Normalisierung für HTML-Entities.
        let normalized = html
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&euro;", with: "€")
            .replacingOccurrences(of: "&#8364;", with: "€")
            .replacingOccurrences(of: "\u{00A0}", with: " ")

        let totalPrice = parseTotalPriceAmount(from: normalized)
        let currency = parseCurrency(from: normalized)

        let roomCountAndCategory = parseRoomCountAndCategory(from: normalized)
        let guestCount = parseGuestCount(from: normalized)

        // Meal/Breakfast ist in den vorhandenen Snapshots nicht immer eindeutig als Klartext enthalten.
        // Daher initial nil lassen und später aus anderen Quellen (z.B. Activity-JSON) füllen.
        let includedBreakfast: Bool? = nil
        let boardTypeRaw: String? = nil

        // Flights/Fähren: erste Implementierung (fail-soft) – wenn es im HTML nicht vorkommt, bleibt es nil.
        let airline: String?
        let passengerCount: Int?
        let baggageInfoRaw: String?
        if bookingType == .hotel {
            airline = nil
            passengerCount = nil
            baggageInfoRaw = nil
        } else {
            airline = parseFirstMatch(forKeyOrLabel: "airline", in: normalized)
                ?? parseFirstMatch(forKeyOrLabel: "carrier", in: normalized)
            passengerCount = parseFirstInteger(forLabels: ["passenger", "Pax", "Reisende"], in: normalized)
            baggageInfoRaw = nil
        }

        let fingerprint = [
            bookingType.rawValue,
            String(describing: totalPrice),
            String(describing: roomCountAndCategory.roomCount),
            String(describing: roomCountAndCategory.roomCategory),
            String(describing: guestCount)
        ].joined(separator: "|")

        return ParsedBookingDetails(
            rawDetailsFingerprint: fingerprint,
            totalPriceAmount: totalPrice,
            totalPriceCurrency: currency,
            roomCategory: roomCountAndCategory.roomCategory,
            boardTypeRaw: boardTypeRaw,
            includedBreakfast: includedBreakfast,
            guestCount: guestCount,
            roomCount: roomCountAndCategory.roomCount,
            airline: airline,
            passengerCount: passengerCount,
            baggageInfoRaw: baggageInfoRaw
        )
    }

    private func parseTotalPriceAmount(from html: String) -> Double? {
        // Normalisieren erfolgt außerhalb dieser Methode.
        // Hier extrahieren wir den Betrag robust aus zwei Layout-Varianten:
        // 1) "effektiver Preis: 123,45 €"
        // 2) "effektiver Preis" (Headline) getrennt vom Wert (z.B. `<div>effektiver Preis</div><div>123,45 €</div>`)

        let amountPattern = #"([0-9]{1,3}(?:\.\d{3})*[\,\.]\d{2}|[0-9]+[\,\.]\d{2})"#
        let amountPatternFlexible = #"(?:([0-9]{1,3}(?:\.\d{3})*[\,\.]\d{2}|[0-9]+[\,\.]\d{2}|[0-9]+))"#

        func parseAmount(_ raw: String) -> Double? {
            let lastComma = raw.lastIndex(of: ",")
            let lastDot = raw.lastIndex(of: ".")

            guard lastComma != nil || lastDot != nil else {
                // JSON kann auch integerbeträge enthalten (z.B. "235" statt "235.00").
                return Double(raw)
            }

            let decimalSeparator: Character = {
                if let comma = lastComma, let dot = lastDot {
                    return comma > dot ? "," : "."
                }
                if lastComma != nil { return "," }
                return "."
            }()

            let thousandSeparator: Character = decimalSeparator == "," ? "." : ","

            let normalized = raw
                .replacingOccurrences(of: String(thousandSeparator), with: "")
                .replacingOccurrences(of: String(decimalSeparator), with: ".")

            return Double(normalized)
        }

        // 0) SSOT aus eingebettetem JSON: immer den Zimmerpreis ("effectivePrice") nehmen.
        // Hintergrund: Der Chooser-Text "effektiver Preis: <Betrag>" kann (bei Multi-Room) zuerst den Basket-Total zeigen.
        let effectivePriceJsonPattern =
            #"\"effectivePrice\"\s*:\s*\{\s*\"amount\"\s*:\s*"# + amountPatternFlexible + #""#

        if let raw = firstRegexMatch(pattern: effectivePriceJsonPattern, in: html) {
            return parseAmount(raw)
        }

        // 1) Klassiker: Label + Doppelpunkt + Betrag
        let inlineColonPattern =
            #"(?:(?:effektiver\s*Preis)|(?:Gesamtpreis)|(?:Gesamtsumme)|(?:Total)|(?:Total\s*Price))\s*:\s*"# + amountPattern + #"\s*(?:€|EUR)"#

        if let raw = firstRegexMatch(pattern: inlineColonPattern, in: html) {
            return parseAmount(raw)
        }

        // 2) Headline getrennt vom Wert (mit beliebigen Tags dazwischen)
        let headlineSeparatedPattern =
            #"(?:(?:effektiver\s+Preis)|(?:Gesamtpreis)|(?:Gesamtsumme)|(?:Total)|(?:Total\s*Price))[^0-9]{0,250}"# + amountPattern + #"\s*(?:€|EUR)"#

        guard let raw = firstRegexMatch(pattern: headlineSeparatedPattern, in: html) else { return nil }
        return parseAmount(raw)
    }

    private func parseCurrency(from html: String) -> String? {
        // Aktuell nur € im Klartext; kann später auf weitere Währungen erweitert werden.
        return html.contains("€") ? "EUR" : nil
    }

    private func parseRoomCountAndCategory(from html: String) -> (roomCount: Int?, roomCategory: String?) {
        // Beispiele:
        // <div class="...-roomName"><strong><span><strong>1x Doppelzimmer</strong></span></strong></div>
        // <div class="...-roomTitle">1x Bungalow</div>
        let patterns = [
            #"roomName[^>]*>.*?<strong>\s*([0-9]+)\s*x\s*([^<]+?)\s*</strong>"#,
            #"roomTitle[^>]*>\s*([0-9]+)\s*x\s*([^<]+?)\s*<"#,
        ]

        var totalRooms = 0
        var categories: [String] = []

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let fullRange = NSRange(html.startIndex..<html.endIndex, in: html)
            let matches = regex.matches(in: html, options: [], range: fullRange)
            for match in matches {
                guard match.numberOfRanges == 3 else { continue }
                let countRange = match.range(at: 1)
                let categoryRange = match.range(at: 2)
                guard countRange.location != NSNotFound, categoryRange.location != NSNotFound else { continue }
                let countText = (html as NSString).substring(with: countRange)
                let category = (html as NSString).substring(with: categoryRange)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard let count = Int(countText), count > 0 else { continue }
                totalRooms += count
                if !category.isEmpty {
                    categories.append(category)
                }
            }
            if totalRooms > 0 { break }
        }

        guard totalRooms > 0 else { return (nil, nil) }
        let category = categories.isEmpty ? nil : categories.joined(separator: " + ")
        return (totalRooms, category)
    }

    private func parseGuestCount(from html: String) -> Int? {
        // Beispiel: guestNames">Danila Liebe, Julian Liebe</div>
        let pattern = #"guestNames[^>]*>\s*([^<]+?)\s*</div>"#
        guard let guestNames = firstRegexMatch(pattern: pattern, in: html) else { return nil }

        // Heuristik: Komma-getrennte Liste der Namens-Tokens.
        let parts = guestNames
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.count
    }

    private func parseFirstMatch(forKeyOrLabel label: String, in html: String) -> String? {
        // fail-soft: versucht Schlüssel/Label sowohl in eingebettetem JSON
        // als auch im Klartext (Label: value) zu finden.
        let escaped = NSRegularExpression.escapedPattern(for: label)

        // JSON-Key:  "airline":"...".
        let jsonPattern = "\"\(escaped)\"\\s*:\\s*\"([^\"]+)\""
        if let match = firstRegexMatch(pattern: jsonPattern, in: html) {
            return match.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Text-Label: Airline: Lufthansa
        let textPattern = "\(escaped)\\s*[:\\-]\\s*([^<]{3,80})"
        if let match = firstRegexMatch(pattern: textPattern, in: html) {
            return match.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private func parseFirstInteger(forLabels labels: [String], in html: String) -> Int? {
        let escapedLabels = labels.map { NSRegularExpression.escapedPattern(for: $0) }
        let joined = escapedLabels.joined(separator: "|")

        // Beispiele:
        // "Reisende: 2"
        // "Pax 2"
        let pattern = "(?:\\b(?:\(joined))\\b)[^0-9]{0,20}([0-9]+)"
        guard let match = firstRegexMatch(pattern: pattern, in: html) else { return nil }
        return Int(match)
    }

    private func firstRegexMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: fullRange) else { return nil }
        guard match.numberOfRanges >= 2 else { return nil }
        let range = match.range(at: 1)
        guard range.location != NSNotFound else { return nil }
        return (text as NSString).substring(with: range)
    }

    private func firstRegexMatchGroups(
        pattern: String,
        in text: String,
        expectedGroups: Int
    ) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: fullRange) else { return nil }
        guard match.numberOfRanges == expectedGroups + 1 else { return nil }

        var results: [String] = []
        for i in 1...expectedGroups {
            let range = match.range(at: i)
            guard range.location != NSNotFound else { return nil }
            results.append((text as NSString).substring(with: range))
        }
        return results
    }
}

