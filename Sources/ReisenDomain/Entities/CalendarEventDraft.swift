import Foundation

/// Pure domain representation of a calendar event we want to sync.
/// The platform layer decides how to resolve missing addresses and how to upsert into EventKit.
public struct CalendarEventDraft: Equatable, Sendable {
    public var role: CalendarEventRole

    public var ownerTripID: UUID
    public var ownerBookingID: UUID?

    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool

    /// Optional timezone hint (offset seconds from GMT). Useful for correct "all-day" spans.
    public var timeZoneOffsetSecondsFromGMT: Int?

    /// Location/address to apply to the calendar event (if already known).
    public var locationAddress: String?

    /// Search query to resolve a missing address (platform uses MapKit).
    public var locationQuery: String?

    /// Optional booking URL to attach to the event.
    public var url: URL?

    /// Notes text (includes meta information like confirmation codes or hotel check-in/out times).
    public var notes: String?
}

