import Foundation
import ReisenDomain

/// Extrahiert Zimmer-/Verpflegungsdaten aus Booking.com Confirmation-HTML.
public struct BookingComHotelConfirmationParser: Sendable {
    public init() {}

    public func parseRateDetails(from html: String) -> BookingRateDetails? {
        let roomCategory = parseRoomCategory(from: html)
        let guestCount = parseGuestCount(from: html)
        let breakfast = parseBreakfastIncluded(from: html)

        guard roomCategory != nil || guestCount != nil || breakfast != nil else {
            return nil
        }

        return BookingRateDetails(
            roomCategory: roomCategory,
            boardType: breakfast == true ? .breakfastIncluded : .unknown,
            includedBreakfast: breakfast,
            guestCount: guestCount
        )
    }
}
