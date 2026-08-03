import Foundation
import ReisenDomain

extension HotelBookingPriceResolver {
    static func catalogPriceSelection(
        booking: ParsedBooking,
        detail: ParsedBookingDetails?
    ) -> PriceSelection {
        PriceSelection(
            amount: booking.catalogPriceAmount,
            currency: booking.catalogPriceCurrency ?? detail?.totalPriceCurrency,
            roomCount: booking.catalogRoomCount ?? 1,
            roomCategory: booking.catalogRoomCategory ?? detail?.roomCategory
        )
    }

    static func detailOrderTotalSelection(
        booking: ParsedBooking,
        detail: ParsedBookingDetails?,
        detailRoomCount: Int?
    ) -> PriceSelection {
        PriceSelection(
            amount: detail?.totalPriceAmount,
            currency: detail?.totalPriceCurrency ?? booking.catalogPriceCurrency,
            roomCount: detailRoomCount,
            roomCategory: detail?.roomCategory ?? booking.catalogRoomCategory
        )
    }

    static func mergedPriceSelection(
        booking: ParsedBooking,
        detail: ParsedBookingDetails?
    ) -> PriceSelection {
        PriceSelection(
            amount: detail?.totalPriceAmount ?? booking.catalogPriceAmount,
            currency: detail?.totalPriceCurrency ?? booking.catalogPriceCurrency,
            roomCount: detail?.roomCount ?? booking.catalogRoomCount,
            roomCategory: detail?.roomCategory ?? booking.catalogRoomCategory
        )
    }
}
