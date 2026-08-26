import Foundation
import ReisenDomain

struct AirbnbActivityReservationDetailsParseResult: Equatable, Sendable {
    let title: String?
    let locationTo: String?
    let locationToAddress: String?
    let guestAdults: Int?
    let deadlines: [CancellationDeadline]
    let rateDetails: BookingRateDetails?
    let confirmationCode: String?
    let experienceWebPath: String?
}

/// Parses Airbnb `activity_reservation_details` JSON by row `id` (not EN label text).
enum AirbnbActivityReservationDetailsParser {
    static func parse(
        responseText: String,
        referenceDate: Date? = nil
    ) throws -> AirbnbActivityReservationDetailsParseResult {
        let decoded = try AirbnbJSONDecoder.shared.decode(
            AirbnbActivityReservationDetailsEnvelope.self,
            from: Data(responseText.utf8)
        )
        let rows = decoded.scheduledEvent.rows
        let byID = rowsByID(rows)

        let marquee = byID["dynamic_marquee_title_image_v3"]?.payload
        let eventLocation = byID["event_location"]?.payload
        let map = byID["map"]?.payload
        let guestCount = byID["guest_count"]?.payload
        let cancelPolicy = byID["cancel_policy"]?.payload
        let payment = byID["payment_summary"]?.payload
        let confirmation = byID["confirmation_code"]?.payload
        let pdp = byID["pdp"]?.payload

        let locationTo = nonEmpty(eventLocation?.subtitle) ?? nonEmpty(map?.addressLine1)
        let locationToAddress = Self.address(
            line1: map?.addressLine1,
            line2: map?.addressLine2
        ) ?? nonEmpty(eventLocation?.subtitle)

        return AirbnbActivityReservationDetailsParseResult(
            title: nonEmpty(marquee?.title),
            locationTo: locationTo,
            locationToAddress: locationToAddress,
            guestAdults: Self.parseGuestAdults(from: guestCount?.subtitle),
            deadlines: Self.parseCancelPolicy(
                subtitle: cancelPolicy?.subtitle,
                referenceDate: referenceDate
            ),
            rateDetails: Self.parsePayment(subtitle: payment?.subtitle),
            confirmationCode: nonEmpty(confirmation?.subtitle),
            experienceWebPath: nonEmpty(pdp?.destination?.webUrl?.value)
        )
    }
}

private extension AirbnbActivityReservationDetailsParser {
    static func address(line1: String?, line2: String?) -> String? {
        let parts = [line1, line2].compactMap { nonEmpty($0) }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }

    static func rowsByID(_ rows: [AirbnbActivityDetailsRow]) -> [String: AirbnbActivityDetailsRow] {
        var byID: [String: AirbnbActivityDetailsRow] = [:]
        for row in rows {
            byID[row.id] = row
        }
        return byID
    }

    static func parseGuestAdults(from subtitle: String?) -> Int? {
        guard let subtitle else { return nil }
        guard let match = subtitle.range(of: #"(\d+)"#, options: .regularExpression) else {
            return nil
        }
        return Int(subtitle[match])
    }

    static func parsePayment(subtitle: String?) -> BookingRateDetails? {
        guard let subtitle, let amount = parseAmount(from: subtitle) else { return nil }
        let cleaned = subtitle.replacingOccurrences(of: "\u{00A0}", with: " ")
        let currency: String?
        if cleaned.uppercased().contains("EUR") || cleaned.contains("€") {
            currency = "EUR"
        } else {
            currency = nil
        }
        return BookingRateDetails(
            totalPriceAmount: amount,
            totalPriceCurrency: currency,
            boardType: .unknown,
            lastParsedAt: Date()
        )
    }

    /// Supports "€41.61 EUR" and German "52,56 €".
    static func parseAmount(from subtitle: String) -> Double? {
        let cleaned = subtitle.replacingOccurrences(of: "\u{00A0}", with: " ")
        guard let match = cleaned.range(
            of: #"([0-9]+[.,][0-9]{2}|[0-9]+)"#,
            options: .regularExpression
        ) else {
            return nil
        }
        let token = String(cleaned[match])
        if token.contains(",") && token.contains(".") {
            // "1.234,56" → strip thousands separator
            return Double(
                token
                    .replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
            )
        }
        if token.contains(",") {
            return Double(token.replacingOccurrences(of: ",", with: "."))
        }
        return Double(token)
    }

    static func parseCancelPolicy(
        subtitle: String?,
        referenceDate: Date?
    ) -> [CancellationDeadline] {
        guard let subtitle, let policyText = nonEmpty(subtitle) else { return [] }
        let lower = policyText.lowercased()
        let isFree = lower.contains("full refund")
            || lower.contains("free cancellation")

        guard let deadlineAt = parseCancelByDate(from: policyText, referenceDate: referenceDate) else {
            // No silent dummy deadline: keep policy only when a concrete deadline is parseable.
            // Spec allows policyText on the deadline; without a date we cannot form CancellationDeadline.
            return []
        }

        return [
            CancellationDeadline(
                deadlineAt: deadlineAt,
                policyText: policyText,
                isStrict: true,
                isFreeCancellation: isFree,
                hotelOffsetSeconds: nil
            )
        ]
    }

    /// e.g. EN: "Get a full refund if you cancel by 9 Aug, 6:00 pm (WIB)."
    static func parseCancelByDate(from text: String, referenceDate: Date?) -> Date? {
        let normalized = normalizeCancelPolicyText(text)
        return parseEnglishCancelByDate(from: normalized, referenceDate: referenceDate)
    }

    static func normalizeCancelPolicyText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    static func parseEnglishCancelByDate(from normalized: String, referenceDate: Date?) -> Date? {
        let pattern =
            #"(?i)cancel by\s+(\d{1,2})\s+([A-Za-z]{3}),?\s+(\d{1,2}):(\d{2})\s*(am|pm)\s*\(([A-Za-z]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = normalized as NSString
        guard let match = regex.firstMatch(
            in: normalized,
            range: NSRange(location: 0, length: ns.length)
        ), match.numberOfRanges == 7
        else {
            return nil
        }

        let day = Int(ns.substring(with: match.range(at: 1)))
        let monthToken = ns.substring(with: match.range(at: 2))
        let hour12 = Int(ns.substring(with: match.range(at: 3)))
        let minute = Int(ns.substring(with: match.range(at: 4)))
        let ampm = ns.substring(with: match.range(at: 5)).lowercased()
        let tzToken = ns.substring(with: match.range(at: 6))

        guard let day, let hour12, let minute, let month = monthNumber(monthToken) else {
            return nil
        }
        guard let timeZone = timeZone(forAbbreviation: tzToken) else { return nil }

        var hour = hour12 % 12
        if ampm == "pm" { hour += 12 }

        return cancelDeadlineDate(
            day: day,
            month: month,
            hour: hour,
            minute: minute,
            timeZone: timeZone,
            referenceDate: referenceDate
        )
    }

    static func cancelDeadlineDate(
        day: Int,
        month: Int,
        hour: Int,
        minute: Int,
        timeZone: TimeZone,
        referenceDate: Date?
    ) -> Date? {
        let year: Int = {
            if let referenceDate {
                return Calendar(identifier: .gregorian).component(.year, from: referenceDate)
            }
            return Calendar(identifier: .gregorian).component(.year, from: Date())
        }()

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return components.date
    }

    static func monthNumber(_ token: String) -> Int? {
        let normalized = token
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .prefix(3)
        let map: [String: Int] = [
            "jan": 1, "feb": 2, "mar": 3, "mär": 3, "apr": 4, "may": 5, "mai": 5,
            "jun": 6, "jul": 7, "aug": 8, "sep": 9, "oct": 10, "okt": 10, "nov": 11,
            "dec": 12, "dez": 12,
        ]
        return map[String(normalized)]
    }

    static func timeZone(forAbbreviation abbreviation: String) -> TimeZone? {
        let token = abbreviation.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch token {
        case "WIB":
            return TimeZone(identifier: "Asia/Jakarta")
        default:
            return TimeZone(abbreviation: token)
        }
    }
}

private func nonEmpty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

// MARK: - DTOs

private struct AirbnbActivityReservationDetailsEnvelope: Decodable {
    let scheduledEvent: AirbnbActivityScheduledEvent

    enum CodingKeys: String, CodingKey {
        case scheduledEvent = "scheduled_event"
    }
}

private struct AirbnbActivityScheduledEvent: Decodable {
    let rows: [AirbnbActivityDetailsRow]
}

private struct AirbnbActivityDetailsRow: Decodable {
    let id: String
    let payload: AirbnbActivityDetailsPayload?
}

private struct AirbnbActivityDetailsPayload: Decodable {
    let title: String?
    let subtitle: String?
    let addressLine1: String?
    let addressLine2: String?
    let destination: AirbnbActivityDetailsDestination?

    enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case addressLine1 = "address_line1"
        case addressLine2 = "address_line2"
        case destination
    }
}

private struct AirbnbActivityDetailsDestination: Decodable {
    let webUrl: AirbnbActivityWebURL?

    enum CodingKeys: String, CodingKey {
        case webUrl = "web_url"
    }
}

private struct AirbnbActivityWebURL: Decodable {
    let value: String?
}
