import Foundation
import ReisenDomain

public extension SDBooking {
    var bookingType: BookingType {
        BookingType(rawValue: bookingTypeRaw) ?? .other
    }

    var status: BookingStatus {
        BookingStatus(rawValue: statusRaw) ?? .unknown
    }

    var provider: ProviderID {
        ProviderID(rawValue: providerRaw)
    }
}

public extension SDGap {
    var kind: GapKind {
        GapKind(rawValue: kindRaw) ?? .both
    }
}

public extension SDBookingRateDetails {
    var boardType: BookingBoardType {
        guard let boardTypeRaw, let value = BookingBoardType(rawValue: boardTypeRaw) else {
            return .unknown
        }
        return value
    }
}
