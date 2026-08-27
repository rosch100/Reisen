import Foundation

extension L10n {
    public static func bookingTypeDisplay(_ type: BookingType) -> String {
        string(bookingTypeKey(type))
    }

    public static func bookingStatusDisplay(_ status: BookingStatus) -> String {
        switch status {
        case .confirmed: return string(.bookingStatusConfirmed)
        case .cancelled: return string(.bookingStatusCancelled)
        case .unknown: return string(.bookingStatusUnknown)
        }
    }

    public static func boardTypeDisplay(_ type: BookingBoardType) -> String {
        switch type {
        case .roomOnly: return string(.bookingBoardRoomOnly)
        case .breakfastIncluded: return string(.bookingBoardBreakfastIncluded)
        case .halfBoard: return string(.bookingBoardHalfBoard)
        case .fullBoard: return string(.bookingBoardFullBoard)
        case .unknown: return string(.bookingBoardUnknown)
        }
    }

    public static func locationFromLabel(for type: BookingType) -> String {
        switch type {
        case .flight: return string(.bookingFieldLocationFromFlight)
        case .ferry: return string(.bookingFieldLocationFromFerry)
        case .carRental: return string(.bookingFieldLocationFromCarRental)
        case .other, .hotel, .activity: return string(.bookingFieldLocationFromOther)
        }
    }

    public static func locationToLabel(for type: BookingType) -> String {
        switch type {
        case .hotel, .activity: return string(.bookingFieldLocationToHotel)
        case .flight, .ferry: return string(.bookingFieldLocationToFlight)
        case .carRental: return string(.bookingFieldLocationToCarRental)
        case .other: return string(.bookingFieldLocationToOther)
        }
    }

    public static func locationFromAddressLabel(for type: BookingType) -> String? {
        switch type {
        case .hotel, .activity: return nil
        case .flight: return string(.bookingFieldLocationFromAddressFlight)
        case .ferry: return string(.bookingFieldLocationFromAddressFerry)
        case .carRental: return string(.bookingFieldLocationFromAddressCarRental)
        case .other: return string(.bookingFieldLocationFromAddressOther)
        }
    }

    public static func locationToAddressLabel(for type: BookingType) -> String? {
        switch type {
        case .hotel: return string(.bookingFieldLocationToAddressHotel)
        case .activity: return string(.bookingFieldLocationToAddressActivity)
        case .flight, .ferry: return string(.bookingFieldLocationToAddressFlight)
        case .carRental: return string(.bookingFieldLocationToAddressCarRental)
        case .other: return string(.bookingFieldLocationToAddressOther)
        }
    }

    public static func roomCategoryLabel(for type: BookingType) -> String? {
        switch type {
        case .hotel: return string(.bookingFieldRoomCategoryHotel)
        case .activity: return string(.bookingFieldRoomCategoryActivity)
        case .carRental: return string(.bookingFieldRoomCategoryCarRental)
        case .other: return string(.bookingFieldRoomCategoryOther)
        case .flight, .ferry: return nil
        }
    }

    public static func roomCountLabel(for type: BookingType) -> String? {
        switch type {
        case .hotel: return string(.bookingFieldRoomCountHotel)
        case .flight, .ferry, .activity, .carRental, .other: return nil
        }
    }

    public static func operatorNameLabel(for type: BookingType) -> String {
        switch type {
        case .activity: return string(.bookingFieldOperatorActivity)
        case .carRental: return string(.bookingFieldOperatorCarRental)
        case .flight, .ferry, .hotel, .other: return string(.bookingFieldOperatorDefault)
        }
    }

    public static func scheduleStartLabel(for type: BookingType) -> String {
        switch type {
        case .hotel: return string(.bookingFieldScheduleStartHotel)
        case .flight: return string(.bookingFieldScheduleStartFlight)
        case .ferry: return string(.bookingFieldScheduleStartFerry)
        case .carRental: return string(.bookingFieldScheduleStartCarRental)
        case .activity, .other: return string(.bookingFieldScheduleStartEvent)
        }
    }

    public static func scheduleEndLabel(for type: BookingType) -> String {
        switch type {
        case .hotel: return string(.bookingFieldScheduleEndHotel)
        case .flight: return string(.bookingFieldScheduleEndFlight)
        case .ferry: return string(.bookingFieldScheduleEndFerry)
        case .carRental: return string(.bookingFieldScheduleEndCarRental)
        case .activity, .other: return string(.bookingFieldScheduleEndEvent)
        }
    }

    public static func overlapLabel(extraCount: Int) -> String {
        if extraCount > 0 {
            return format(.bookingOverlapWithCount, extraCount)
        }
        return string(.bookingOverlap)
    }

    public static func cancellationFreeUntilText(deadlineAt formattedDeadline: String) -> String {
        format(.bookingCancellationFreeUntil, formattedDeadline)
    }

    public static func cancellationPaidUntilText(deadlineAt formattedDeadline: String) -> String {
        format(.bookingCancellationPaidUntil, formattedDeadline)
    }

    private static func bookingTypeKey(_ type: BookingType) -> L10nKey {
        switch type {
        case .flight: return .bookingTypeFlight
        case .hotel: return .bookingTypeHotel
        case .ferry: return .bookingTypeFerry
        case .activity: return .bookingTypeActivity
        case .carRental: return .bookingTypeCarRental
        case .other: return .bookingTypeOther
        }
    }
}
