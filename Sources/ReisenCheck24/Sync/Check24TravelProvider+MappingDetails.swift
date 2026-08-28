import Foundation
import ReisenDomain

extension ParsedBookingDetails {
    static func merging(
        _ primary: ParsedBookingDetails?,
        with secondary: ParsedBookingDetails?
    ) -> ParsedBookingDetails? {
        BookingRateDetails.merging(
            existing: secondary?.asRateDetails(),
            incoming: primary?.asRateDetails()
        ).map(ParsedBookingDetails.init(rateDetails:))
    }

    func asRateDetails(lastParsedAt: Date = Date()) -> BookingRateDetails {
        BookingRateDetails(
            rawDetailsFingerprint: rawDetailsFingerprint.flatMap { $0.isEmpty ? nil : $0 },
            totalPriceAmount: totalPriceAmount,
            totalPriceCurrency: totalPriceCurrency,
            roomCategory: roomCategory,
            boardType: BookingBoardType.parse(boardTypeRaw),
            includedBreakfast: includedBreakfast,
            guestCount: guestCount,
            roomCount: roomCount,
            airline: airline,
            passengerCount: passengerCount,
            baggageInfoRaw: baggageInfoRaw,
            lastParsedAt: lastParsedAt
        )
    }
}

extension ParsedCancellationDeadline {
    var asDomain: CancellationDeadline {
        CancellationDeadline(
            deadlineAt: deadlineAt,
            policyText: policyText,
            isStrict: isStrict,
            isFreeCancellation: isFreeCancellation,
            hotelOffsetSeconds: hotelOffsetSeconds,
            cancellationFeeAmount: cancellationFeeAmount
        )
    }

    init(_ deadline: CancellationDeadline) {
        self.init(
            deadlineAt: deadline.deadlineAt,
            policyText: deadline.policyText,
            isStrict: deadline.isStrict,
            isFreeCancellation: deadline.isFreeCancellation,
            hotelOffsetSeconds: deadline.hotelOffsetSeconds,
            cancellationFeeAmount: deadline.cancellationFeeAmount
        )
    }
}
