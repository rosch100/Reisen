import Foundation
import ReisenDomain

extension DomainMapper {
    public static func rateDetails(from model: SDBookingRateDetails) -> BookingRateDetails {
        BookingRateDetails(
            id: model.id,
            bookingID: model.booking?.id,
            rawDetailsFingerprint: model.rawDetailsFingerprint,
            totalPriceAmount: model.totalPriceAmount,
            totalPriceCurrency: model.totalPriceCurrency,
            roomCategory: model.roomCategory,
            boardType: BookingBoardType(rawValue: model.boardTypeRaw ?? "") ?? .unknown,
            includedBreakfast: model.includedBreakfast,
            guestCount: model.guestCount,
            roomCount: model.roomCount,
            airline: model.airline,
            passengerCount: model.passengerCount,
            baggageInfoRaw: model.baggageInfoRaw,
            roomItems: (model.roomItems ?? []).map(roomItem(from:)),
            lastParsedAt: model.lastParsedAt
        )
    }

    public static func roomItem(from model: SDBookingRoomItem) -> BookingRoomItem {
        BookingRoomItem(
            id: model.id,
            category: model.category,
            confirmationCode: model.confirmationCode,
            priceAmount: model.priceAmount,
            priceCurrency: model.priceCurrency,
            guestSummary: model.guestSummary,
            externalUrl: model.externalUrl,
            sortIndex: model.sortIndex
        )
    }
}
