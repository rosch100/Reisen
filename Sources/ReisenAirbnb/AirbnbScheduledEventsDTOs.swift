import Foundation

struct AirbnbScheduledEventsEnvelope: Decodable {
    let scheduledEvent: AirbnbScheduledEvent
    let metadata: AirbnbScheduledEventsMetadata

    enum CodingKeys: String, CodingKey {
        case scheduledEvent = "scheduled_event"
        case metadata
    }
}

struct AirbnbScheduledEventsMetadata: Decodable {
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

struct AirbnbScheduledEvent: Decodable {
    let rows: [AirbnbScheduledEventRow]
}
