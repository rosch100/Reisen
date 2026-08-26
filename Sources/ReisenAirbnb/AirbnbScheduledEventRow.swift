import Foundation

struct AirbnbScheduledEventRow: Decodable {
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
