import Foundation
import ReisenDomain

/// SSOT: Opodo Trip-Detail mit Stornofeldern.
/// HAR (`www.opodo.de` 2026-07-18 entry 797): Hotel-„Stornierungsrichtlinie“ kommt ausschließlich
/// aus `accommodationProductBooking.cancellationPolicies` (Fragment `HotelInformation`).
/// Die erweiterte Query mit `accommodationBooking.*` / `itinerary.*` liefert HTTP 400.
public enum OpodoGetTripByTokenQuery {
    /// HAR-stabile Minimalquery + Statusfelder (Storno erkennen, auch ohne Fristen).
    public static let query = """
    query getTripByToken($token: String!) {
      getTrip: getTripByToken(token: $token) {
        trip {
          bookingStatus
          bookingProductStatus
          accommodationBooking {
            bookingStatus
          }
          accommodationProductBooking {
            cancellationPolicies {
              cancellableStatus
              cancellationOptions {
                from
                until
                refundAmount {
                  amount
                  currency
                }
                refundPercentage
              }
            }
          }
        }
      }
    }
    """

    public static func requestBody(token: String) throws -> Data {
        let payload: [String: Any] = [
            "query": query,
            "operationName": "getTripByToken",
            "variables": ["token": token],
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    /// Token aus `…#tripdetails/td=<token>`.
    public static func tdToken(fromExternalURL urlString: String) -> String? {
        guard let marker = urlString.range(of: "#tripdetails/td=") else { return nil }
        let raw = String(urlString[marker.upperBound...])
        let token = raw.split(whereSeparator: { $0 == "/" || $0 == "?" || $0 == "&" || $0 == "#" }).first
        guard let token, !token.isEmpty else { return nil }
        return String(token)
    }
}

/// Parst Stornofristen / Status aus `getTripByToken` JSON.
public struct OpodoTripCancellationGraphQLParser: Sendable {
    public init() {}

    public func parseDeadlines(from json: String) throws -> [CancellationDeadline] {
        try parse(from: json).deadlines
    }

    public func parse(from json: String) throws -> OpodoTripCancellationParseResult {
        guard let data = json.data(using: .utf8) else {
            throw OpodoTripCancellationGraphQLParserError.invalidJSON
        }
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw OpodoTripCancellationGraphQLParserError.invalidJSON
        }

        guard let trip = envelope.data?.getTrip?.trip else {
            return OpodoTripCancellationParseResult(deadlines: [], status: nil)
        }

        let status = Self.status(
            bookingStatus: trip.accommodationBooking?.bookingStatus ?? trip.bookingStatus,
            productStatus: trip.bookingProductStatus,
            cancellableStatus: trip.accommodationProductBooking?.cancellationPolicies?.cancellableStatus
                ?? trip.accommodationBooking?.cancellationPolicies?.cancellableStatus
                ?? trip.accommodationBooking?.cancellationInformation?.cancellableStatus
        )

        var deadlines: [CancellationDeadline] = []
        let isHotelTrip = trip.accommodationBooking != nil || trip.accommodationProductBooking != nil

        deadlines.append(contentsOf: flightDeadlinesIfApplicable(trip: trip, isHotelTrip: isHotelTrip))

        // HAR UI: Stornierungsrichtlinie = accommodationProductBooking.cancellationPolicies
        let productOptions = trip.accommodationProductBooking?.cancellationPolicies?.cancellationOptions
        let productDeadlines = deadlinesFromCancellationOptions(productOptions, policyLabel: "Stornierungsrichtlinie")
        if !productDeadlines.isEmpty {
            deadlines.append(contentsOf: productDeadlines)
        } else if let hotel = trip.accommodationBooking {
            deadlines.append(contentsOf: hotelDeadlinesFallback(from: hotel))
        }

        let deduped = dedupeDeadlines(deadlines)
        return OpodoTripCancellationParseResult(
            deadlines: deduped.sorted { $0.deadlineAt < $1.deadlineAt },
            status: status
        )
    }

    /// Erkennt stornierte Trips in GraphQL-Statusfeldern bzw. Opodo-Detail-HTML.
    /// Wichtig: `CANCELLABLE` enthält „CANCEL“, ist aber kein Storno.
    public static func status(
        bookingStatus: String?,
        productStatus: String?,
        cancellableStatus: String? = nil
    ) -> BookingStatus? {
        let tokens = [bookingStatus, productStatus, cancellableStatus]
            .compactMap { $0?.uppercased() }
        if tokens.contains(where: isCancelledStatusToken) {
            return .cancelled
        }
        return nil
    }

    public static func isCancelledStatusToken(_ raw: String) -> Bool {
        let token = raw.uppercased()
        if token.contains("CANCELLABLE") || token.contains("CANCELABLE") {
            return false
        }
        if token.contains("CANCELLED") || token.contains("CANCELED") {
            return true
        }
        // Opodo BookingStatus (HAR Schema): stornierte Hotels kommen als RETAINED/FINAL_RET,
        // nicht als CANCELLED. Trip-Ebene bleibt oft CONTRACT.
        if token == "RETAINED" || token == "FINAL_RET" {
            return true
        }
        if token == "DIDNOTBUY" || token == "DID_NOT_BUY" || token == "VOID" {
            return true
        }
        // Reine Tokens wie "CANCEL" / "CANCELED_BY_USER"
        if token == "CANCEL" || token.hasPrefix("CANCEL_") || token.hasSuffix("_CANCEL") {
            return true
        }
        return false
    }

    public static func looksCancelled(inPageText text: String) -> Bool {
        let lower = text.lowercased()
        // Bewusst „storniert“ / „cancelled“, nicht „Stornierungsrichtlinie“ / „cancellation“.
        if lower.contains("storniert") { return true }
        if lower.range(of: #"\bcancelled\b"#, options: .regularExpression) != nil { return true }
        if lower.contains("booking canceled") || lower.contains("booking cancelled") { return true }
        return false
    }
}

public struct OpodoTripCancellationParseResult: Equatable, Sendable {
    public var deadlines: [CancellationDeadline]
    public var status: BookingStatus?

    public init(deadlines: [CancellationDeadline], status: BookingStatus?) {
        self.deadlines = deadlines
        self.status = status
    }
}

public enum OpodoTripCancellationGraphQLParserError: LocalizedError, Sendable {
    case invalidJSON

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Opodo Trip-Storno GraphQL konnte nicht gelesen werden."
        }
    }
}

private extension OpodoTripCancellationGraphQLParser {
    func flightDeadlinesIfApplicable(
        trip: TripDTO,
        isHotelTrip: Bool
    ) -> [CancellationDeadline] {
        guard !isHotelTrip, let itinerary = trip.itinerary else { return [] }

        var deadlines: [CancellationDeadline] = []

        if let iso = itinerary.freeCancellation, let parsed = parseISODate(iso) {
            deadlines.append(
                CancellationDeadline(
                    deadlineAt: parsed.date,
                    policyText: "Opodo freeCancellation",
                    isStrict: true,
                    isFreeCancellation: true,
                    hotelOffsetSeconds: parsed.offsetSeconds
                )
            )
        }

        if let limit = itinerary.freeCancellationLimit?.limitTime,
           let date = dateFromEpochMillis(limit) {
            deadlines.append(
                CancellationDeadline(
                    deadlineAt: date,
                    policyText: "Opodo freeCancellationLimit",
                    isStrict: true,
                    isFreeCancellation: true,
                    hotelOffsetSeconds: 0
                )
            )
        }

        return deadlines
    }

    func hotelDeadlinesFallback(from hotel: AccommodationDTO) -> [CancellationDeadline] {
        let policyStrings = [
            hotel.roomsGroupCancelPolicy,
            hotel.bookingCancelPolicy,
            hotel.accommodationCancelPolicy
        ].compactMap { $0 }.filter { !$0.isEmpty }

        let parsedFromPolicyStrings: [CancellationDeadline] = {
            guard !policyStrings.isEmpty else { return [] }
            let html = policyStrings.joined(separator: "\n")
            return OpodoCancellationDeadlineParser().parseDeadlines(from: html)
        }()

        let policyLines = parsedFromPolicyStrings.filter {
            ($0.policyText ?? "").localizedCaseInsensitiveContains("Stornierungsrichtlinie")
                || ($0.policyText ?? "").range(of: #"\d{1,2}\.?\s*[A-Za-zÄÖÜäöü]+\s+\d{4}"#, options: .regularExpression) != nil
        }
        if !policyLines.isEmpty {
            return policyLines
        }

        var deadlines: [CancellationDeadline] = []
        if let iso = hotel.cancellationDate, let parsed = parseISODate(iso) {
            deadlines.append(
                CancellationDeadline(
                    deadlineAt: parsed.date,
                    policyText: "Opodo cancellationDate",
                    isStrict: true,
                    isFreeCancellation: true,
                    hotelOffsetSeconds: parsed.offsetSeconds
                )
            )
        }

        let optionGroups = [
            hotel.cancellationInformation?.cancellationOptions,
            hotel.cancellationPolicies?.cancellationOptions
        ]
        for options in optionGroups {
            deadlines.append(contentsOf: deadlinesFromCancellationOptions(options, policyLabel: nil))
        }

        return deadlines
    }

    func dedupeDeadlines(_ deadlines: [CancellationDeadline]) -> [CancellationDeadline] {
        var byKey: [String: CancellationDeadline] = [:]
        for deadline in deadlines {
            let feeKey = deadline.cancellationFeeAmount.map { String($0) } ?? ""
            let key = "\(Int(deadline.deadlineAt.timeIntervalSince1970))|\(deadline.isFreeCancellation)|\(feeKey)"
            byKey[key] = deadline
        }
        return Array(byKey.values)
    }

    /// Wie Opodo-UI: 100 % → Vollständige Rückerstattung; bei mehreren 100 %-Fenstern das späteste.
    func deadlinesFromCancellationOptions(
        _ options: [CancellationOptionDTO]?,
        policyLabel: String?
    ) -> [CancellationDeadline] {
        guard let options, !options.isEmpty else { return [] }

        var freeOptions: [CancellationDeadline] = []
        var paid: [CancellationDeadline] = []
        for option in options {
            guard let until = option.until, let parsed = parseISODate(until) else { continue }
            let pct = option.refundPercentage ?? 0
            let deadline = CancellationDeadline(
                deadlineAt: parsed.date,
                policyText: policyText(for: option, label: policyLabel),
                isStrict: true,
                isFreeCancellation: pct >= 100,
                hotelOffsetSeconds: parsed.offsetSeconds,
                cancellationFeeAmount: nil
            )
            if pct >= 100 {
                freeOptions.append(deadline)
            } else {
                paid.append(deadline)
            }
        }

        var result = paid
        if let latestFree = freeOptions.max(by: { $0.deadlineAt < $1.deadlineAt }) {
            result.append(latestFree)
        }
        return result
    }

    func policyText(for option: CancellationOptionDTO, label: String?) -> String {
        let pct = option.refundPercentage ?? 0
        let until = option.until ?? ""
        if pct >= 100 {
            let prefix = label ?? "Stornierungsrichtlinie"
            return "\(prefix) (Vollständige Rückerstattung bis \(until))"
        }
        let amount = option.refundAmount.map { "\($0.amount) \($0.currency)" } ?? ""
        return "Erstattung \(pct)% \(amount) (bis \(until))".trimmingCharacters(in: .whitespaces)
    }

    /// Parst ISO-Zeit inkl. Offset. HAR: `2026-08-01T22:00:00-00:00` → Anzeige 1.8. 22:00
    /// (nicht Geräte-Lokalzeit 2.8. 00:00 in CEST).
    func parseISODate(_ raw: String) -> (date: Date, offsetSeconds: Int)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // HAR/UI: `new Date(until)` — ISO und epoch-ms als String.
        if let millis = Int64(trimmed), trimmed.count >= 12,
           let date = dateFromEpochMillis(millis) {
            return (date, 0)
        }

        let offsetSeconds = isoOffsetSeconds(in: trimmed) ?? 0

        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFrac.date(from: trimmed) {
            return (date, offsetSeconds)
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: trimmed) {
            return (date, offsetSeconds)
        }

        // JS Date oft ohne Zeitzone: 2026-08-01T22:00:00 — wie Opodo-UI als Wall-Clock UTC.
        if trimmed.count >= 19,
           trimmed[trimmed.index(trimmed.startIndex, offsetBy: 10)] == "T" {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = f.date(from: String(trimmed.prefix(19))) {
                return (date, 0)
            }
        }

        // Nur Datum (yyyy-MM-dd)
        let day = String(trimmed.prefix(10))
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: day) else { return nil }
        return (date, 0)
    }

    /// Offset aus ISO-Suffix (`Z`, `±HH:MM`, `±HHMM`). Fehlt → nil.
    func isoOffsetSeconds(in raw: String) -> Int? {
        if raw.hasSuffix("Z") || raw.hasSuffix("z") { return 0 }
        guard let regex = try? NSRegularExpression(
            pattern: #"([+-])(\d{2}):?(\d{2})$"#
        ) else { return nil }
        let ns = raw as NSString
        guard let match = regex.firstMatch(
            in: raw,
            options: [],
            range: NSRange(location: 0, length: ns.length)
        ), match.numberOfRanges == 4 else { return nil }
        let sign = ns.substring(with: match.range(at: 1)) == "-" ? -1 : 1
        guard let hours = Int(ns.substring(with: match.range(at: 2))),
              let minutes = Int(ns.substring(with: match.range(at: 3))) else { return nil }
        return sign * (hours * 3600 + minutes * 60)
    }

    func dateFromEpochMillis(_ raw: Int64) -> Date? {
        Date(timeIntervalSince1970: TimeInterval(raw) / 1000)
    }
}

// MARK: - DTOs

private struct Envelope: Decodable {
    let data: DataContainer?
}

private struct DataContainer: Decodable {
    let getTrip: TripContainer?
}

private struct TripContainer: Decodable {
    let trip: TripDTO?
}

private struct TripDTO: Decodable {
    let id: String?
    let bookingStatus: String?
    let bookingProductStatus: String?
    let itinerary: ItineraryDTO?
    let accommodationBooking: AccommodationDTO?
    let accommodationProductBooking: AccommodationProductBookingDTO?
}

private struct AccommodationProductBookingDTO: Decodable {
    let cancellationPolicies: CancellationPoliciesDTO?
}

private struct ItineraryDTO: Decodable {
    let freeCancellation: String?
    let freeCancellationLimit: FreeCancellationLimitDTO?
}

private struct FreeCancellationLimitDTO: Decodable {
    let limitTime: Int64?
    let hoursApart: Int64?
}

private struct AccommodationDTO: Decodable {
    let bookingStatus: String?
    let cancellationDate: String?
    let roomsGroupCancelPolicy: String?
    let bookingCancelPolicy: String?
    let accommodationCancelPolicy: String?
    let cancellationInformation: CancellationInformationDTO?
    let cancellationPolicies: CancellationPoliciesDTO?
}

private struct CancellationInformationDTO: Decodable {
    let cancellableStatus: String?
    let cancellationOptions: [CancellationOptionDTO]?
}

private struct CancellationPoliciesDTO: Decodable {
    let cancellableStatus: String?
    let cancellationOptions: [CancellationOptionDTO]?
}

private struct CancellationOptionDTO: Decodable {
    let from: String?
    let until: String?
    let refundAmount: MoneyDTO?
    let refundPercentage: Int?
}

private struct MoneyDTO: Decodable {
    let amount: Double
    let currency: String
}
