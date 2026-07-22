import Foundation
import ReisenDomain

enum AirbnbScheduledEventsParser {
    static func parse(
        responseText: String
    ) throws -> AirbnbScheduledEventsParseResult {
        let decoded = try JSONDecoder.airbnb.decode(
            AirbnbScheduledEventsEnvelope.self,
            from: Data(responseText.utf8)
        )
        let rows = decoded.scheduledEvent.rows

        let hotelCheckInMinutes = parseMinutesRow(rows: rows, rowID: "checkin_checkout_arrival_guide", which: .checkIn)
        let hotelCheckOutMinutes = parseMinutesRow(rows: rows, rowID: "checkin_checkout_arrival_guide", which: .checkOut)

        let rateDetails = parsePaymentSummary(rows: rows)
        let deadlines = parseCancellationDeadlines(rows: rows)

        return AirbnbScheduledEventsParseResult(
            deadlines: deadlines,
            rateDetails: rateDetails,
            hotelCheckInMinutes: hotelCheckInMinutes,
            hotelCheckOutMinutes: hotelCheckOutMinutes
        )
    }
}

struct AirbnbScheduledEventsParseResult {
    let deadlines: [CancellationDeadline]
    let rateDetails: BookingRateDetails?
    let hotelCheckInMinutes: Int?
    let hotelCheckOutMinutes: Int?
}

private extension AirbnbScheduledEventsParser {
    enum Which {
        case checkIn
        case checkOut
    }

    static func parseMinutesRow(
        rows: [AirbnbScheduledEventRow],
        rowID: String,
        which: Which
    ) -> Int? {
        let row = rows.first(where: { $0.id == rowID })
        guard let row else { return nil }

        let timeString: String? = {
            switch which {
            case .checkIn:
                return row.leadingSubtitle
            case .checkOut:
                return row.trailingSubtitle
            }
        }()

        guard let timeString else { return nil }
        // Expected format: "23:00" (German UI).
        let parts = timeString.split(separator: ":")
        guard parts.count == 2, let hh = Int(parts[0]), let mm = Int(parts[1]) else { return nil }
        guard hh >= 0, hh < 24, mm >= 0, mm < 60 else { return nil }
        return hh * 60 + mm
    }

    static func parsePaymentSummary(rows: [AirbnbScheduledEventRow]) -> BookingRateDetails? {
        let row = rows.first(where: { $0.id == "payment_summary" })
        guard let row, let subtitle = row.subtitle else { return nil }

        // Expected pattern: "52,56 €" (German decimal separator).
        let cleaned = subtitle.replacingOccurrences(of: "\u{00A0}", with: " ")
        let currency: String? = cleaned.contains("€") ? "EUR" : nil

        // Extract first numeric token with comma/dot.
        guard let match = cleaned.range(of: #"([0-9]{1,3}([.,][0-9]{2})?)"#, options: .regularExpression) else {
            return nil
        }
        let numberToken = String(cleaned[match])
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")

        guard let amount = Double(numberToken) else { return nil }

        return BookingRateDetails(
            totalPriceAmount: amount,
            totalPriceCurrency: currency,
            boardType: .unknown,
            lastParsedAt: Date()
        )
    }

    static func parseCancellationDeadlines(rows: [AirbnbScheduledEventRow]) -> [CancellationDeadline] {
        let row = rows.first(where: { $0.id == "cancellation_visualization" })
        guard let row else { return [] }

        // In this HAR, cancellation milestones are encoded in `cancellation_milestone_modal_v2.entries[]`.
        guard let modalEntries = row.cancellationMilestoneModalV2?.entries else { return [] }

        return modalEntries.compactMap { entry in
            guard let startAt = entry.startAt else { return nil }
            let refundType = (entry.refundType ?? "").lowercased()
            let refundTerm = entry.refundTerm
            let termLower = (refundTerm ?? "").lowercased()

            // Avoid dummy defaults: only set `isFreeCancellation` when we can classify.
            let isFree: Bool?
            if refundType.contains("keine rückerstattung") || termLower.contains("nicht erstattungsfähig") {
                isFree = false
            } else if refundType.contains("kostenlose") || termLower.contains("kostenlos") {
                isFree = true
            } else {
                // Unknown policy wording in captured content.
                isFree = nil
            }

            guard let isFree else { return nil }

            return CancellationDeadline(
                deadlineAt: startAt,
                policyText: refundTerm ?? entry.timelineTitle,
                isStrict: true,
                isFreeCancellation: isFree
            )
        }
    }
}

// MARK: - Response Model (subset)

private struct AirbnbScheduledEventsEnvelope: Decodable {
    let scheduledEvent: AirbnbScheduledEvent
    let metadata: AirbnbScheduledEventsMetadata

    enum CodingKeys: String, CodingKey {
        case scheduledEvent = "scheduled_event"
        case metadata
    }
}

private struct AirbnbScheduledEventsMetadata: Decodable {
    // Kept for completeness; not used in current parsing.
    let title: String?
    let checkInDate: String?
    let checkOutDate: String?
    let timezone: String?

    enum CodingKeys: String, CodingKey {
        case title
        case checkInDate = "check_in_date"
        case checkOutDate = "check_out_date"
        case timezone
    }
}

private struct AirbnbScheduledEvent: Decodable {
    let rows: [AirbnbScheduledEventRow]
}

private struct AirbnbScheduledEventRow: Decodable {
    let id: String

    // check-in/out row.
    let leadingSubtitle: String?
    let trailingSubtitle: String?

    // payment row.
    let subtitle: String?

    // cancellation row.
    let cancellationMilestoneModalV2: CancellationMilestoneModalV2?

    // Cancellation visualizations contain different keys across versions.
    // We model only the V2 modal here.
    struct CancellationMilestoneModalV2: Decodable {
        let entries: [CancellationMilestoneEntry]?
    }

    struct CancellationMilestoneEntry: Decodable {
        let timelineTitle: String?
        let refundType: String?
        let refundTerm: String?
        let startAt: Date?

        // Not used for deadlineAt, but included in the schema.
        let endAt: Date?

        enum CodingKeys: String, CodingKey {
            case timelineTitle = "timeline_title"
            case refundType = "refund_type"
            case refundTerm = "refund_term"
            case startAt = "start_at"
            case endAt = "end_at"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id

        case leadingSubtitle = "leading_subtitle"
        case trailingSubtitle = "trailing_subtitle"
        case subtitle

        case cancellationMilestoneModalV2 = "cancellation_milestone_modal_v2"
    }
}

private extension JSONDecoder {
    static let airbnb: JSONDecoder = {
        let decoder = JSONDecoder()
        // Airbnb uses RFC3339 timestamps for start_at/end_at in this endpoint.
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

