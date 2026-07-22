import Foundation

@MainActor
public protocol ReminderScheduling: AnyObject {
    func scheduleCancellationDeadlines(
        deadlines: [CancellationDeadline],
        bookingTitles: [UUID: String],
        leadTimesDays: [Int]
    ) async throws -> [Reminder]
}

@MainActor
public protocol CalendarSyncing: AnyObject {
    func syncCancellationDeadlines(
        trips: [Trip],
        bookings: [Booking],
        deadlines: [CancellationDeadline],
        bookingTitles: [UUID: String],
        eventCalendarTitle: String,
        reminderCalendarTitle: String,
        eventCreateIfMissing: Bool,
        reminderCreateIfMissing: Bool,
        calendarTitleMode: CalendarTitleMode,
        leadTimesDays: [Int]
    ) async throws

    func syncTripTimelineEntries(
        trips: [Trip],
        bookings: [Booking],
        bookingTitles: [UUID: String],
        eventCalendarTitle: String,
        eventCreateIfMissing: Bool,
        includeTripStartEnd: Bool,
        includeFlightTimes: Bool,
        includeHotelStays: Bool
    ) async throws
}

public protocol AddressResolving {
    /// Resolve a human-readable address/location string from a search query (e.g. IATA code, hotel name).
    /// Returns `nil` if no match could be resolved.
    func resolveAddress(query: String) async throws -> String?
}
