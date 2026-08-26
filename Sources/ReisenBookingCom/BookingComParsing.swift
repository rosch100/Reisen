import Foundation

/// Shared parsing helpers for Booking.com HTML/JSON/GraphQL (SSOT).
///
/// Implementations live in:
/// - `BookingComParsing+Regex`
/// - `BookingComParsing+Dates` / `+DatesLong` / `+DatesStorage`
/// - `BookingComParsing+URLs` / `+CatalogHelpers`
enum BookingComParsing {
    static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
