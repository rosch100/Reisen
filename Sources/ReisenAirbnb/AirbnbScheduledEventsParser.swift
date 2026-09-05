import Foundation
import ReisenDomain

struct AirbnbScheduledEventsParseResult {
    let deadlines: [CancellationDeadline]
    let rateDetails: BookingRateDetails?
    let hotelCheckInMinutes: Int?
    let hotelCheckOutMinutes: Int?
}

enum AirbnbScheduledEventsParser {
    static func parse(
        responseText: String,
        hotelOffsetSeconds: Int?
    ) throws -> AirbnbScheduledEventsParseResult {
        let decoded = try AirbnbJSONDecoder.shared.decode(
            AirbnbScheduledEventsEnvelope.self,
            from: Data(responseText.utf8)
        )
        let rows = decoded.scheduledEvent.rows

        return AirbnbScheduledEventsParseResult(
            deadlines: AirbnbScheduledEventsCancellation.parse(
                rows: rows,
                hotelOffsetSeconds: hotelOffsetSeconds
            ),
            rateDetails: AirbnbScheduledEventsPayment.parse(rows: rows),
            hotelCheckInMinutes: AirbnbScheduledEventsMinutes.parse(
                rows: rows,
                rowID: "checkin_checkout_arrival_guide",
                which: .checkIn
            ),
            hotelCheckOutMinutes: AirbnbScheduledEventsMinutes.parse(
                rows: rows,
                rowID: "checkin_checkout_arrival_guide",
                which: .checkOut
            )
        )
    }
}
