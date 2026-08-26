import Foundation
import ReisenDomain

extension Check24TravelProvider {
    func mergeBookingDetails(
        primary: ParsedBookingDetails?,
        secondary: ParsedBookingDetails?
    ) -> ParsedBookingDetails? {
        switch (primary, secondary) {
        case let (p?, s?):
            return ParsedBookingDetails(
                rawDetailsFingerprint: p.rawDetailsFingerprint,
                totalPriceAmount: p.totalPriceAmount ?? s.totalPriceAmount,
                totalPriceCurrency: p.totalPriceCurrency ?? s.totalPriceCurrency,
                roomCategory: p.roomCategory ?? s.roomCategory,
                boardTypeRaw: p.boardTypeRaw ?? s.boardTypeRaw,
                includedBreakfast: p.includedBreakfast ?? s.includedBreakfast,
                guestCount: p.guestCount ?? s.guestCount,
                roomCount: p.roomCount ?? s.roomCount,
                airline: p.airline ?? s.airline,
                passengerCount: p.passengerCount ?? s.passengerCount,
                baggageInfoRaw: p.baggageInfoRaw ?? s.baggageInfoRaw
            )
        case let (p?, nil):
            return p
        case let (nil, s?):
            return s
        case (nil, nil):
            return nil
        }
    }

    func mapDeadline(_ parsed: ParsedCancellationDeadline) -> CancellationDeadline {
        CancellationDeadline(
            deadlineAt: parsed.deadlineAt,
            policyText: parsed.policyText,
            isStrict: parsed.isStrict,
            isFreeCancellation: parsed.isFreeCancellation,
            hotelOffsetSeconds: parsed.hotelOffsetSeconds,
            cancellationFeeAmount: parsed.cancellationFeeAmount
        )
    }

    func mapRateDetails(_ parsed: ParsedBookingDetails) -> BookingRateDetails {
        BookingRateDetails(
            rawDetailsFingerprint: parsed.rawDetailsFingerprint,
            totalPriceAmount: parsed.totalPriceAmount,
            totalPriceCurrency: parsed.totalPriceCurrency,
            roomCategory: parsed.roomCategory,
            boardType: BookingBoardType(rawValue: parsed.boardTypeRaw ?? "") ?? .unknown,
            includedBreakfast: parsed.includedBreakfast,
            guestCount: parsed.guestCount,
            roomCount: parsed.roomCount,
            airline: parsed.airline,
            passengerCount: parsed.passengerCount,
            baggageInfoRaw: parsed.baggageInfoRaw,
            lastParsedAt: Date()
        )
    }
}
