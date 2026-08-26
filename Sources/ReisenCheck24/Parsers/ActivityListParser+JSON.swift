import Foundation
import ReisenDomain

extension ActivityListParser {
    func looksLikeActivitiesJSON(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{" || trimmed.first == "[" else { return false }
        return trimmed.contains("\"activities\"")
    }

    /// Unterstützt:
    /// - Live-API: `{ "activities":[ { startDate, endDate, link, product, detail, ... } ] }`
    /// - HAR/ältere Form: `{ "data":{ "activities":[ { start_date, product_specific_data.booking_uuid, ... } ] } }`
    func parseActivitiesJSON(from text: String) throws -> ParsedActivity {
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
}
