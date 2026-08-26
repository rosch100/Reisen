import Foundation
import ReisenDomain

extension HotelBookingPriceResolver {
    struct PriceSelection: Sendable {
        let amount: Double?
        let currency: String?
        let roomCount: Int?
        let roomCategory: String?
    }

    static func selectPriceFields(
        booking: ParsedBooking,
        siblings: [ParsedBooking],
        detail: ParsedBookingDetails?
    ) -> PriceSelection {
        let sameStaySiblings = siblings.filter { isSameHotelStay($0, booking) }
        let detailRoomCount = detail?.roomCount
        let hasLinkedMultiRoomActivities = sameStaySiblings.count > 1
        let mode = priceSelectionMode(
            booking: booking,
            hasLinkedMultiRoomActivities: hasLinkedMultiRoomActivities,
            detailRoomCount: detailRoomCount,
            detail: detail
        )
        switch mode {
        case .catalog:
            return catalogPriceSelection(booking: booking, detail: detail)
        case .detailOrderTotal:
            return detailOrderTotalSelection(booking: booking, detail: detail, detailRoomCount: detailRoomCount)
        case .merged:
            return mergedPriceSelection(booking: booking, detail: detail)
        }
    }
}
